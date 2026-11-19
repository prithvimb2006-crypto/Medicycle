from backend.utils.auth import permission_required
from flask import Blueprint, jsonify, request, current_app
from mysql.connector import Error, IntegrityError

from backend.database.connection import get_db_connection

medicine_bp = Blueprint("medicines", __name__, url_prefix="/api/medicines")


@medicine_bp.route("", methods=["GET"])
def get_medicines():
    """List and search active medicines."""

    connection = None
    cursor = None

    try:
        search = request.args.get("q", "").strip()
        limit = min(max(request.args.get("limit", 20, type=int), 1), 100)
        offset = max(request.args.get("offset", 0, type=int), 0)

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        query = """
            SELECT
                m.medicine_id,
                m.brand_name,
                m.generic_name,
                m.dosage_form,
                m.strength,
                m.administration_route,
                m.prescription_classification,
                c.category_name,
                mf.name AS manufacturer_name
            FROM medicines m
            LEFT JOIN categories c
                ON m.category_id = c.category_id
            LEFT JOIN manufacturers mf
                ON m.manufacturer_id = mf.manufacturer_id
            WHERE m.is_active = 1
        """

        params = []

        if search:
            query += """
                AND (
                    m.brand_name LIKE %s
                    OR m.generic_name LIKE %s
                    OR mf.name LIKE %s
                )
            """
            search_term = f"%{search}%"
            params.extend([search_term, search_term, search_term])

        query += """
            ORDER BY m.brand_name ASC
            LIMIT %s OFFSET %s
        """

        params.extend([limit, offset])

        cursor.execute(query, tuple(params))
        medicines = cursor.fetchall()

        return jsonify({
            "status": "success",
            "count": len(medicines),
            "limit": limit,
            "offset": offset,
            "data": medicines
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve medicines"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@medicine_bp.route("/<int:medicine_id>", methods=["GET"])
def get_medicine_details(medicine_id):
    """Retrieve a complete medicine profile."""

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        # Main medicine information
        cursor.execute("""
            SELECT
                m.medicine_id,
                m.brand_name,
                m.generic_name,
                m.dosage_form,
                m.strength,
                m.administration_route,
                m.prescription_classification,
                m.barcode_upc,
                m.ndc_number,
                m.is_active,
                m.category_id,
                m.manufacturer_id,
                c.category_name,
                mf.name AS manufacturer_name,
                mf.country AS manufacturer_country,
                m.reference_id
            FROM medicines m
            LEFT JOIN categories c
                ON m.category_id = c.category_id
            LEFT JOIN manufacturers mf
                ON m.manufacturer_id = mf.manufacturer_id
            WHERE m.medicine_id = %s
        """, (medicine_id,))

        medicine = cursor.fetchone()

        if not medicine:
            return jsonify({
                "status": "error",
                "message": "Medicine not found"
            }), 404

        # Ingredients and composition
        cursor.execute("""
            SELECT
                i.ingredient_id,
                i.generic_name,
                i.drug_class,
                i.description,
                mc.strength_value,
                mc.strength_unit,
                mc.is_active_ingredient
            FROM medicine_compositions mc
            JOIN ingredients i
                ON mc.ingredient_id = i.ingredient_id
            WHERE mc.medicine_id = %s
        """, (medicine_id,))

        ingredients = cursor.fetchall()

        # Documented uses
        cursor.execute("""
            SELECT
                use_id,
                indication,
                target_condition,
                is_fda_approved,
                reference_id
            FROM medicine_uses
            WHERE medicine_id = %s
        """, (medicine_id,))

        uses = cursor.fetchall()

        # Storage information
        cursor.execute("""
            SELECT
                min_temp_celsius,
                max_temp_celsius,
                requires_refrigeration,
                light_sensitive,
                moisture_sensitive,
                storage_instructions,
                excursion_limit_hours
            FROM storage_rules
            WHERE medicine_id = %s
        """, (medicine_id,))

        storage = cursor.fetchone()

        return jsonify({
            "status": "success",
            "data": {
                "medicine": medicine,
                "ingredients": ingredients,
                "documented_uses": uses,
                "storage": storage
            }
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve medicine profile"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()

def _text(value):
    return str(value).strip() if value is not None else ""


def _number(value):
    """Blank -> None, otherwise float. Raises ValueError for bad input."""
    if value is None or str(value).strip() == "":
        return None
    return float(value)


@medicine_bp.route("", methods=["POST"])
@permission_required("CATALOG_WRITE")
def create_medicine():
    data = request.get_json(silent=True) or {}

    required = [
        "brand_name", "generic_name", "category_id",
        "manufacturer_id", "dosage_form", "strength",
        "administration_route"
    ]
    missing = [field for field in required if not data.get(field)]
    if missing:
        return jsonify({
            "success": False,
            "message": "Missing fields: " + ", ".join(missing)
        }), 400

    ingredients = data.get("ingredients") or []
    uses = data.get("uses") or []
    side_effects = data.get("side_effects") or []
    contraindications = data.get("contraindications") or []
    storage = data.get("storage") or None

    if not all(isinstance(x, list) for x in
               (ingredients, uses, side_effects, contraindications)):
        return jsonify({"success": False, "message": "Invalid request format."}), 400

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT category_id FROM categories WHERE category_id=%s",
            (data["category_id"],)
        )
        if not cursor.fetchone():
            return jsonify({"success": False, "message": "Invalid category ID."}), 400

        cursor.execute(
            "SELECT manufacturer_id FROM manufacturers WHERE manufacturer_id=%s",
            (data["manufacturer_id"],)
        )
        if not cursor.fetchone():
            return jsonify({"success": False, "message": "Invalid manufacturer ID."}), 400

        cursor.execute("""
            INSERT INTO medicines (
                brand_name, generic_name, category_id, manufacturer_id,
                dosage_form, strength, administration_route,
                prescription_classification, barcode_upc, ndc_number
            )
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            _text(data["brand_name"]),
            _text(data["generic_name"]),
            data["category_id"],
            data["manufacturer_id"],
            _text(data["dosage_form"]),
            _text(data["strength"]),
            _text(data["administration_route"]),
            _text(data.get("prescription_classification")) or "PRESCRIPTION_ONLY",
            _text(data.get("barcode_upc")) or None,
            _text(data.get("ndc_number")) or None
        ))
        medicine_id = cursor.lastrowid

        # Ingredients: reuse an existing ingredient by name, otherwise create it
        for ing in ingredients:
            name = _text(ing.get("name"))
            if not name:
                continue

            cursor.execute(
                "SELECT ingredient_id FROM ingredients "
                "WHERE LOWER(generic_name) = LOWER(%s) LIMIT 1",
                (name,)
            )
            row = cursor.fetchone()
            if row:
                ingredient_id = row["ingredient_id"]
            else:
                cursor.execute(
                    "INSERT INTO ingredients (generic_name, drug_class) VALUES (%s, %s)",
                    (name, _text(ing.get("drug_class")) or None)
                )
                ingredient_id = cursor.lastrowid

            cursor.execute("""
                INSERT INTO medicine_compositions
                    (medicine_id, ingredient_id, strength_value,
                     strength_unit, is_active_ingredient)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                medicine_id, ingredient_id,
                _number(ing.get("strength_value")),
                _text(ing.get("strength_unit")) or None,
                1 if ing.get("is_active", True) else 0
            ))

        for use in uses:
            indication = _text(use.get("indication"))
            if indication:
                cursor.execute("""
                    INSERT INTO medicine_uses
                        (medicine_id, indication, target_condition, is_fda_approved)
                    VALUES (%s, %s, %s, %s)
                """, (
                    medicine_id, indication,
                    _text(use.get("target_condition")) or None,
                    1 if use.get("is_fda_approved") else 0
                ))

        if storage:
            cursor.execute("""
                INSERT INTO storage_rules
                    (medicine_id, min_temp_celsius, max_temp_celsius,
                     requires_refrigeration, light_sensitive, moisture_sensitive,
                     storage_instructions, excursion_limit_hours)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                medicine_id,
                _number(storage.get("min_temp_celsius")),
                _number(storage.get("max_temp_celsius")),
                1 if storage.get("requires_refrigeration") else 0,
                1 if storage.get("light_sensitive") else 0,
                1 if storage.get("moisture_sensitive") else 0,
                _text(storage.get("storage_instructions")) or None,
                _number(storage.get("excursion_limit_hours"))
            ))

        for se in side_effects:
            reaction = _text(se.get("adverse_reaction"))
            if reaction:
                cursor.execute("""
                    INSERT INTO side_effects
                        (medicine_id, adverse_reaction, frequency,
                         severity, requires_medical_attention)
                    VALUES (%s, %s, %s, %s, %s)
                """, (
                    medicine_id, reaction,
                    _text(se.get("frequency")) or None,
                    _text(se.get("severity")).upper() or "MODERATE",
                    1 if se.get("requires_medical_attention") else 0
                ))

        for ci in contraindications:
            condition = _text(ci.get("condition_name"))
            if condition:
                cursor.execute("""
                    INSERT INTO contraindications
                        (medicine_id, condition_name, type, clinical_rationale)
                    VALUES (%s, %s, %s, %s)
                """, (
                    medicine_id, condition,
                    _text(ci.get("type")).upper() or "ABSOLUTE",
                    _text(ci.get("clinical_rationale")) or None
                ))

        connection.commit()

        return jsonify({
            "success": True,
            "message": "Medicine added successfully.",
            "medicine_id": medicine_id
        }), 201

    except ValueError:
        if connection:
            connection.rollback()
        return jsonify({
            "success": False,
            "message": "Strength, temperature and hour values must be numbers."
        }), 400

    except IntegrityError:
        if connection:
            connection.rollback()
        return jsonify({
            "success": False,
            "message": "Duplicate value: barcode, NDC number or a repeated ingredient already exists."
        }), 409

    except Error:
        if connection:
            connection.rollback()
        current_app.logger.exception("create_medicine failed")
        return jsonify({
            "success": False,
            "message": "Could not save the medicine. Check the values and try again."
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@medicine_bp.route("/<int:medicine_id>", methods=["PUT"])
@permission_required("CATALOG_WRITE")
def update_medicine(medicine_id):
    data = request.get_json(silent=True) or {}

    fields = [
        "brand_name", "generic_name", "category_id",
        "manufacturer_id", "dosage_form", "strength",
        "administration_route", "prescription_classification",
        "barcode_upc", "ndc_number"
    ]

    required = fields[:7]
    missing = [field for field in required if not data.get(field)]
    if missing:
        return jsonify({
            "success": False,
            "message": "Missing fields: " + ", ".join(missing)
        }), 400

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute("""
            UPDATE medicines
            SET brand_name=%s,
                generic_name=%s,
                category_id=%s,
                manufacturer_id=%s,
                dosage_form=%s,
                strength=%s,
                administration_route=%s,
                prescription_classification=%s,
                barcode_upc=%s,
                ndc_number=%s
            WHERE medicine_id=%s AND is_active=1
        """, (
            data["brand_name"].strip(),
            data["generic_name"].strip(),
            data["category_id"],
            data["manufacturer_id"],
            data["dosage_form"],
            data["strength"].strip(),
            data["administration_route"].strip(),
            data.get("prescription_classification", "PRESCRIPTION_ONLY"),
            data.get("barcode_upc") or None,
            data.get("ndc_number") or None,
            medicine_id
        ))

        if cursor.rowcount == 0:
            connection.rollback()
            return jsonify({
                "success": False,
                "message": "Medicine not found or no changes made."
            }), 404

        connection.commit()
        return jsonify({"success": True, "message": "Medicine updated successfully."})

    except IntegrityError:
        if connection:
            connection.rollback()
        return jsonify({"success": False, "message": "Duplicate barcode or NDC number."}), 409

    except Error:
        if connection:
            connection.rollback()
        current_app.logger.exception("medicine write failed")
        return jsonify({"success": False, "message": "Could not save changes. Check the values and try again."}), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@medicine_bp.route("/<int:medicine_id>", methods=["DELETE"])
@permission_required("CATALOG_WRITE")
def deactivate_medicine(medicine_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute("""
            UPDATE medicines
            SET is_active=0
            WHERE medicine_id=%s AND is_active=1
        """, (medicine_id,))

        if cursor.rowcount == 0:
            connection.rollback()
            return jsonify({
                "success": False,
                "message": "Medicine not found or already inactive."
            }), 404

        connection.commit()
        return jsonify({
            "success": True,
            "message": "Medicine deactivated successfully."
        })

    except IntegrityError:
        if connection:
            connection.rollback()
        return jsonify({"success": False, "message": "Duplicate barcode or NDC number."}), 409

    except Error:
        if connection:
            connection.rollback()
        current_app.logger.exception("medicine write failed")
        return jsonify({"success": False, "message": "Could not save changes. Check the values and try again."}), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()

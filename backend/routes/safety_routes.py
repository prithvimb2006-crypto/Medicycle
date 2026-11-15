
from flask import Blueprint, jsonify
from mysql.connector import Error
from backend.database.connection import get_db_connection

safety_bp = Blueprint("medicine_safety", __name__)


@safety_bp.route("/<int:medicine_id>/safety", methods=["GET"])
def get_medicine_safety(medicine_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT medicine_id, brand_name FROM medicines "
            "WHERE medicine_id = %s AND is_active = 1",
            (medicine_id,)
        )
        medicine = cursor.fetchone()

        if not medicine:
            return jsonify({
                "status": "error",
                "message": "Medicine not found"
            }), 404

        cursor.execute("""
            SELECT
                side_effect_id,
                adverse_reaction,
                frequency,
                severity,
                requires_medical_attention
            FROM side_effects
            WHERE medicine_id = %s
            ORDER BY
                CASE severity
                    WHEN 'LIFE_THREATENING' THEN 1
                    WHEN 'SEVERE' THEN 2
                    WHEN 'MODERATE' THEN 3
                    ELSE 4
                END
        """, (medicine_id,))

        side_effects = cursor.fetchall()

        cursor.execute("""
            SELECT
                contraindication_id,
                condition_name,
                type,
                clinical_rationale
            FROM contraindications
            WHERE medicine_id = %s
            ORDER BY type ASC
        """, (medicine_id,))

        contraindications = cursor.fetchall()

        return jsonify({
            "status": "success",
            "data": {
                "medicine": medicine,
                "side_effects": side_effects,
                "contraindications": contraindications
            }
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve medicine safety information"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@safety_bp.route(
    "/<int:medicine_id>/interactions/<int:other_medicine_id>",
    methods=["GET"]
)
def check_medicine_interactions(medicine_id, other_medicine_id):
    connection = None
    cursor = None

    if medicine_id == other_medicine_id:
        return jsonify({
            "status": "error",
            "message": "Please provide two different medicine IDs"
        }), 400

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT medicine_id, brand_name
            FROM medicines
            WHERE medicine_id IN (%s, %s)
              AND is_active = 1
        """, (medicine_id, other_medicine_id))

        medicines = cursor.fetchall()

        if len(medicines) != 2:
            return jsonify({
                "status": "error",
                "message": "One or both medicines were not found"
            }), 404

        cursor.execute("""
            SELECT DISTINCT
                di.interaction_id,
                i1.generic_name AS ingredient_1,
                i2.generic_name AS ingredient_2,
                di.severity,
                di.mechanism,
                di.clinical_effect,
                di.management_advice,
                sr.reference_id,
                sr.source_name,
                sr.publication_title,
                sr.url,
                sr.verification_status
            FROM medicine_compositions mc1
            JOIN medicine_compositions mc2
                ON mc1.ingredient_id <> mc2.ingredient_id
            JOIN drug_interactions di
                ON (
                    di.ingredient1_id = mc1.ingredient_id
                    AND di.ingredient2_id = mc2.ingredient_id
                )
                OR (
                    di.ingredient2_id = mc1.ingredient_id
                    AND di.ingredient1_id = mc2.ingredient_id
                )
            JOIN ingredients i1
                ON di.ingredient1_id = i1.ingredient_id
            JOIN ingredients i2
                ON di.ingredient2_id = i2.ingredient_id
            LEFT JOIN source_references sr
                ON di.reference_id = sr.reference_id
            WHERE mc1.medicine_id = %s
              AND mc2.medicine_id = %s
        """, (medicine_id, other_medicine_id))

        interactions = cursor.fetchall()

        return jsonify({
            "status": "success",
            "medicine_ids": [medicine_id, other_medicine_id],
            "interaction_count": len(interactions),
            "data": interactions,
            "message": (
                "No documented interaction was found in the database."
                if not interactions
                else "Documented interaction records retrieved."
            )
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to check medicine interactions"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()


@safety_bp.route("/<int:medicine_id>/references", methods=["GET"])
def get_medicine_references(medicine_id):
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT medicine_id
            FROM medicines
            WHERE medicine_id = %s AND is_active = 1
        """, (medicine_id,))

        if not cursor.fetchone():
            return jsonify({
                "status": "error",
                "message": "Medicine not found"
            }), 404

        cursor.execute("""
            SELECT DISTINCT
                sr.reference_id,
                sr.source_name,
                sr.source_type,
                sr.url,
                sr.publication_title,
                sr.edition_or_version,
                sr.retrieval_date,
                sr.verification_status
            FROM source_references sr
            WHERE sr.reference_id IN (
                SELECT reference_id
                FROM medicines
                WHERE medicine_id = %s
                  AND reference_id IS NOT NULL

                UNION

                SELECT reference_id
                FROM medicine_uses
                WHERE medicine_id = %s
                  AND reference_id IS NOT NULL

                UNION

                SELECT i.reference_id
                FROM medicine_compositions mc
                JOIN ingredients i
                    ON mc.ingredient_id = i.ingredient_id
                WHERE mc.medicine_id = %s
                  AND i.reference_id IS NOT NULL
            )
            ORDER BY sr.retrieval_date DESC
        """, (medicine_id, medicine_id, medicine_id))

        references = cursor.fetchall()

        return jsonify({
            "status": "success",
            "count": len(references),
            "data": references
        }), 200

    except Error:
        return jsonify({
            "status": "error",
            "message": "Unable to retrieve medicine references"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()

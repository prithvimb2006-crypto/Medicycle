
const API = "/api";

let currentUser = null;
let medicineSearchTimer = null;

const $ = (id) => document.getElementById(id);

function escapeHTML(value) {
    return String(value ?? "").replace(/[&<>"']/g, char => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
    })[char]);
}

async function apiRequest(url, options = {}) {
    const response = await fetch(url, {
        credentials: "same-origin",
        ...options,
        headers: {
            "Content-Type": "application/json",
            ...(options.headers || {})
        }
    });

    const data = await response.json().catch(() => ({}));

    if (response.status === 401) {
        showLogin();
        throw new Error("Authentication required.");
    }

    if (!response.ok) {
        throw new Error(data.message || `Request failed: ${response.status}`);
    }

    return data;
}

/* =========================================================
   LOGIN AND REGISTRATION
========================================================= */

function showLogin() {
    document.querySelector(".app-container").style.display = "none";

    let login = $("login-screen");

    if (!login) {
        login = document.createElement("div");
        login.id = "login-screen";

        login.innerHTML = `
            <div class="login-card">
                <div class="brand-icon">M</div>
                <h1>MEDICYCLE</h1>
                <p>Medicine Intelligence & Safety Platform</p>

                <div id="login-view">
                    <form id="login-form">
                        <label>Username or Email</label>
                        <input id="login-identifier"
                            required autocomplete="username"
                            placeholder="Enter username or email">

                        <label>Password</label>
                        <input id="login-password" type="password"
                            required autocomplete="current-password"
                            placeholder="Enter password">

                        <button class="primary-btn" type="submit">
                            Sign in
                        </button>

                        <p id="login-error"></p>
                    </form>

                    <p>
                        New staff member?
                        <button type="button" class="text-button"
                            id="show-register">
                            Register here
                        </button>
                    </p>
                </div>

                <div id="register-view" style="display:none;">
                    <h3>Staff Registration</h3>

                    <form id="register-form">
                        <label>Full Name</label>
                        <input id="register-name" required
                            placeholder="Enter full name">

                        <label>Username</label>
                        <input id="register-username" required
                            autocomplete="username"
                            placeholder="Choose username">

                        <label>Email</label>
                        <input id="register-email" type="email"
                            required placeholder="Enter email">

                        <label>Password</label>
                        <input id="register-password" type="password"
                            required minlength="8"
                            autocomplete="new-password"
                            placeholder="Minimum 8 characters">

                        <label>Staff Role</label>
                        <select id="register-role" required>
                            <option value="">Select role</option>
                            <option value="DOCTOR">Doctor</option>
                            <option value="NURSE">Nurse</option>
                            <option value="RECEPTIONIST">Receptionist</option>
                        </select>

                        <button class="primary-btn" type="submit">
                            Submit Registration
                        </button>

                        <p id="register-error"></p>
                    </form>

                    <p>
                        Already registered?
                        <button type="button" class="text-button"
                            id="show-login">
                            Sign in
                        </button>
                    </p>
                </div>
            </div>
        `;

        document.body.appendChild(login);

        $("login-form").addEventListener("submit", async event => {
            event.preventDefault();

            const button = event.submitter;
            const error = $("login-error");

            error.textContent = "";
            button.disabled = true;
            button.textContent = "Signing in...";

            try {
                await apiRequest(`${API}/auth/login`, {
                    method: "POST",
                    body: JSON.stringify({
                        identifier: $("login-identifier").value.trim(),
                        password: $("login-password").value
                    })
                });

                $("login-password").value = "";
                login.style.display = "none";

                document.querySelector(".app-container").style.display = "flex";

                await initializeApp();

            } catch (err) {
                error.textContent = err.message;
            } finally {
                button.disabled = false;
                button.textContent = "Sign in";
            }
        });

        $("register-form").addEventListener("submit", async event => {
            event.preventDefault();

            const button = event.submitter;
            const error = $("register-error");

            error.textContent = "";
            button.disabled = true;
            button.textContent = "Submitting...";

            try {
                const result = await apiRequest(`${API}/auth/register`, {
                    method: "POST",
                    body: JSON.stringify({
                        full_name: $("register-name").value.trim(),
                        username: $("register-username").value.trim(),
                        email: $("register-email").value.trim(),
                        password: $("register-password").value,
                        role: $("register-role").value
                    })
                });

                $("register-form").reset();

                alert(result.message || "Registration submitted.");

                $("register-view").style.display = "none";
                $("login-view").style.display = "block";

            } catch (err) {
                error.textContent = err.message;
            } finally {
                button.disabled = false;
                button.textContent = "Submit Registration";
            }
        });

        $("show-register").addEventListener("click", () => {
            $("login-view").style.display = "none";
            $("register-view").style.display = "block";
        });

        $("show-login").addEventListener("click", () => {
            $("register-view").style.display = "none";
            $("login-view").style.display = "block";
        });
    }

    login.style.display = "grid";
}

/* =========================================================
   APPLICATION INITIALIZATION
========================================================= */

async function initializeApp() {
    try {
        const result = await apiRequest(`${API}/auth/me`);
        currentUser = result.user;

        $("user-name").textContent =
            currentUser.full_name || currentUser.username;

        $("user-role").textContent = currentUser.role;

        $("user-avatar").textContent =
            (currentUser.full_name || currentUser.username)
                .charAt(0).toUpperCase();

        $("overview-role").textContent = currentUser.role;

        $("current-date").textContent =
            new Date().toLocaleDateString("en-IN", {
                day: "numeric",
                month: "long",
                year: "numeric"
            });

        const isAdmin = currentUser.role === "ADMIN";

        $("admin-nav").style.display = isAdmin ? "block" : "none";

        await loadDashboard();

    } catch (error) {
        if (error.message !== "Authentication required.") {
            showNotification(error.message);
        }
    }
}

function showNotification(message) {
    const notification = $("notification");

    notification.textContent = message;
    notification.style.display = "block";

    setTimeout(() => {
        notification.style.display = "none";
    }, 3500);
}

/* =========================================================
   TABLE HELPERS
========================================================= */

function showTable(headers, rows) {
    if (!rows || rows.length === 0) {
        return "<p>No records found.</p>";
    }

    return `
        <table>
            <thead>
                <tr>
                    ${headers.map(h => `<th>${escapeHTML(h)}</th>`).join("")}
                </tr>
            </thead>
            <tbody>
                ${rows.map(row => `
                    <tr>
                        ${row.map(cell => `
                            <td>${escapeHTML(cell)}</td>
                        `).join("")}
                    </tr>
                `).join("")}
            </tbody>
        </table>
    `;
}

function extractRecords(result) {
    if (Array.isArray(result)) return result;

    for (const key of [
        "data", "medicines", "recalls", "batches", "results"
    ]) {
        if (Array.isArray(result?.[key])) return result[key];
    }

    return [];
}

/* =========================================================
   DASHBOARD
========================================================= */

async function loadDashboard() {
    try {
        const [
            medicineData,
            recallData,
            batchData,
            expiringData
        ] = await Promise.all([
            apiRequest(`${API}/medicines?limit=100`),
            apiRequest(`${API}/recalls`),
            apiRequest(`${API}/batches/summary`),
            apiRequest(`${API}/batches/expiring?days=30`)
        ]);

        const medicines = extractRecords(medicineData);
        const recalls = extractRecords(recallData);
        const expiring = extractRecords(expiringData);

        $("total-medicines").textContent =
            medicineData.count ?? medicines.length;

        $("total-recalls").textContent =
            recallData.count ?? recalls.length;

        $("total-batches").textContent =
            batchData.total_batches ?? batchData.total ?? "--";

        $("expiring-batches").textContent =
            expiringData.count ?? expiring.length;

        $("recent-medicines").innerHTML = showTable(
            ["Medicine", "Generic Name", "Strength"],
            medicines.slice(0, 6).map(m => [
                m.brand_name,
                m.generic_name,
                m.strength
            ])
        );

    } catch (error) {
        showNotification("Dashboard loading issue: " + error.message);
    }
}

/* =========================================================
   MEDICINE CATALOGUE
========================================================= */

async function loadMedicines(search = "") {
    const container = $("medicine-results");
    container.innerHTML = "Loading catalogue...";

    try {
        const data = await apiRequest(
            `${API}/medicines?q=${encodeURIComponent(search)}&limit=100`
        );

        const medicines = extractRecords(data);

        container.innerHTML = showTable(
            ["ID", "Brand", "Generic", "Strength", "Form", "Manufacturer"],
            medicines.map(m => [
                m.medicine_id,
                m.brand_name,
                m.generic_name,
                m.strength,
                m.dosage_form,
                m.manufacturer_name
            ])
        );

    } catch (error) {
        container.textContent = error.message;
    }
}

/* =========================================================
   READABLE SAFETY INFORMATION
========================================================= */

async function loadSafety() {
    const id = $("safety-id").value.trim();

    if (!id || Number(id) <= 0) {
        showNotification("Enter a valid medicine ID.");
        return;
    }

    const container = $("safety-results");
    container.innerHTML = "Loading safety information...";

    try {
        const response = await apiRequest(
            `${API}/medicines/${id}/safety`
        );

        const data = response.data || response;
        const medicine = data.medicine || {};
        const sideEffects = data.side_effects || [];
        const contraindications = data.contraindications || [];

        container.innerHTML = `
            <div class="panel" style="margin-top:20px;">
                <h3>Medicine Information</h3>

                <p><strong>Brand:</strong>
                    ${escapeHTML(medicine.brand_name || "Not available")}
                </p>

                <p><strong>Generic:</strong>
                    ${escapeHTML(medicine.generic_name || "Not available")}
                </p>

                <p><strong>Medicine ID:</strong>
                    ${escapeHTML(medicine.medicine_id || id)}
                </p>
            </div>

            <div class="panel" style="margin-top:20px;">
                <h3>Documented Side Effects</h3>

                ${
                    sideEffects.length
                    ? sideEffects.map(effect => `
                        <div class="system-item">
                            <div>
                                <strong>
                                    ${escapeHTML(effect.adverse_reaction)}
                                </strong>
                                <p>
                                    Frequency:
                                    ${escapeHTML(effect.frequency || "Not specified")}
                                </p>
                                <p>
                                    Severity:
                                    ${escapeHTML(effect.severity || "Not specified")}
                                </p>
                                <p>
                                    Medical attention required:
                                    ${effect.requires_medical_attention ? "Yes" : "Not indicated"}
                                </p>
                            </div>
                        </div>
                    `).join("")
                    : "<p>No documented side-effect records found.</p>"
                }
            </div>

            <div class="panel" style="margin-top:20px;">
                <h3>Contraindications</h3>

                ${
                    contraindications.length
                    ? contraindications.map(item => `
                        <div class="system-item">
                            <div>
                                <strong>
                                    ${escapeHTML(item.condition_name)}
                                </strong>
                                <p>
                                    Type:
                                    ${escapeHTML(item.type || "Not specified")}
                                </p>
                                <p>
                                    Clinical rationale:
                                    ${escapeHTML(item.clinical_rationale || "Not provided")}
                                </p>
                            </div>
                        </div>
                    `).join("")
                    : "<p>No documented contraindication records found.</p>"
                }
            </div>

            <div class="panel" style="margin-top:20px;">
                <p>
                    <strong>Important:</strong>
                    This information reflects records currently available
                    in the MEDICYCLE database. Missing records do not
                    establish that a medicine is safe. Consult a qualified
                    healthcare professional for clinical decisions.
                </p>
            </div>
        `;

    } catch (error) {
        container.textContent = error.message;
    }
}

/* =========================================================
   RECALLS
========================================================= */

async function loadRecalls() {
    const container = $("recall-results");
    container.textContent = "Loading recall records...";

    try {
        const data = await apiRequest(`${API}/recalls`);
        const records = extractRecords(data);

        container.innerHTML = showTable(
            ["Reference", "Authority", "Class", "Status", "Date"],
            records.map(r => [
                r.recall_reference_code,
                r.issuing_authority,
                r.recall_class,
                r.status,
                r.announcement_date
            ])
        );

    } catch (error) {
        container.textContent = error.message;
    }
}

/* =========================================================
   BATCHES
========================================================= */

async function loadBatches() {
    const container = $("batch-results");
    container.textContent = "Loading batch records...";

    try {
        const data = await apiRequest(`${API}/batches`);
        const records = extractRecords(data);

        container.innerHTML = showTable(
            ["Batch ID", "Medicine ID", "Batch Number", "Expiry", "Status"],
            records.map(b => [
                b.batch_id,
                b.medicine_id,
                b.batch_number,
                b.expiry_date,
                b.status
            ])
        );

    } catch (error) {
        container.textContent = error.message;
    }
}

/* =========================================================
   ADMIN: USER MANAGEMENT
========================================================= */

async function loadAdminUsers() {
    if (currentUser?.role !== "ADMIN") return;

    const container = $("admin-users");
    container.textContent = "Loading users...";

    try {
        const result = await apiRequest(`${API}/auth/admin/users`);
        const users = result.users || [];

        if (!users.length) {
            container.innerHTML = "<p>No users found.</p>";
            return;
        }

        container.innerHTML = `
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Username</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Last Login</th>
                        <th>Actions</th>
                    </tr>
                </thead>

                <tbody>
                    ${users.map(user => {
                        const isStaff = [
                            "DOCTOR", "NURSE", "RECEPTIONIST"
                        ].includes(user.role);

                        const actions = isStaff
                            ? user.account_status === "PENDING"
                                ? `
                                    <button class="primary-btn"
                                        data-user-action="APPROVED"
                                        data-user-id="${Number(user.user_id)}">
                                        Approve
                                    </button>
                                    <button class="text-button"
                                        data-user-action="REJECTED"
                                        data-user-id="${Number(user.user_id)}">
                                        Reject
                                    </button>
                                `
                                : `
                                    <button class="text-button"
                                        data-user-action="${user.account_status === "APPROVED" ? "REJECTED" : "APPROVED"}"
                                        data-user-id="${Number(user.user_id)}">
                                        ${user.account_status === "APPROVED" ? "Revoke access" : "Approve"}
                                    </button>
                                `
                            : "—";

                        return `
                            <tr>
                                <td>${escapeHTML(user.full_name)}</td>
                                <td>${escapeHTML(user.username)}</td>
                                <td>${escapeHTML(user.email)}</td>
                                <td>${escapeHTML(user.role)}</td>
                                <td>${escapeHTML(user.account_status)}</td>
                                <td>${escapeHTML(user.last_login_at || "Never")}</td>
                                <td>${actions}</td>
                            </tr>
                        `;
                    }).join("")}
                </tbody>
            </table>
        `;

    } catch (error) {
        container.textContent = error.message;
    }
}

$("admin-users").addEventListener("click", async event => {
    const button = event.target.closest("[data-user-action]");

    if (!button || currentUser?.role !== "ADMIN") return;

    const userId = button.dataset.userId;
    const status = button.dataset.userAction;

    const confirmed = confirm(
        `Are you sure you want to set this user's status to ${status}?`
    );

    if (!confirmed) return;

    button.disabled = true;

    try {
        const result = await apiRequest(
            `${API}/auth/admin/users/${userId}/status`,
            {
                method: "PATCH",
                body: JSON.stringify({ status })
            }
        );

        showNotification(result.message);
        await loadAdminUsers();

    } catch (error) {
        showNotification(error.message);
        button.disabled = false;
    }
});

/* =========================================================
   ADMIN: MEDICINE MANAGEMENT
========================================================= */

async function loadAdminMedicines() {
    if (currentUser?.role !== "ADMIN") return;

    const container = $("admin-medicines");
    container.textContent = "Loading medicines...";

    try {
        const data = await apiRequest(`${API}/medicines?limit=100`);
        const medicines = extractRecords(data);

        if (!medicines.length) {
            container.innerHTML = "<p>No medicines found.</p>";
            return;
        }

        container.innerHTML = `
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Brand</th>
                        <th>Generic</th>
                        <th>Strength</th>
                        <th>Actions</th>
                    </tr>
                </thead>

                <tbody>
                    ${medicines.map(m => `
                        <tr>
                            <td>${escapeHTML(m.medicine_id)}</td>
                            <td>${escapeHTML(m.brand_name)}</td>
                            <td>${escapeHTML(m.generic_name)}</td>
                            <td>${escapeHTML(m.strength)}</td>
                            <td>
                                <button class="text-button"
                                    data-edit-medicine="${Number(m.medicine_id)}">
                                    Edit
                                </button>

                                <button class="text-button"
                                    data-delete-medicine="${Number(m.medicine_id)}">
                                    Deactivate
                                </button>
                            </td>
                        </tr>
                    `).join("")}
                </tbody>
            </table>
        `;

    } catch (error) {
        container.textContent = error.message;
    }
}

function resetMedicineForm() {
    $("medicine-form").reset();
    $("edit-medicine-id").value = "";
    $("save-medicine").textContent = "Add Medicine";
}

$("medicine-form").addEventListener("submit", async event => {
    event.preventDefault();

    if (currentUser?.role !== "ADMIN") {
        showNotification("Admin access required.");
        return;
    }

    const medicineId = $("edit-medicine-id").value;

    const payload = {
        brand_name: $("med-brand").value.trim(),
        generic_name: $("med-generic").value.trim(),
        category_id: Number($("med-category").value),
        manufacturer_id: Number($("med-manufacturer").value),
        dosage_form: $("med-form").value,
        strength: $("med-strength").value.trim(),
        administration_route: $("med-route").value.trim(),
        prescription_classification: $("med-classification").value,
        barcode_upc: $("med-barcode").value.trim() || null,
        ndc_number: $("med-ndc").value.trim() || null
    };

    const button = $("save-medicine");
    button.disabled = true;

    try {
        const result = await apiRequest(
            medicineId
                ? `${API}/medicines/${medicineId}`
                : `${API}/medicines`,
            {
                method: medicineId ? "PUT" : "POST",
                body: JSON.stringify(payload)
            }
        );

        showNotification(result.message || "Medicine saved successfully.");

        resetMedicineForm();

        await Promise.all([
            loadAdminMedicines(),
            loadMedicines(),
            loadDashboard()
        ]);

    } catch (error) {
        showNotification(error.message);
    } finally {
        button.disabled = false;
    }
});

$("admin-medicines").addEventListener("click", async event => {
    if (currentUser?.role !== "ADMIN") return;

    const editButton = event.target.closest("[data-edit-medicine]");
    const deleteButton = event.target.closest("[data-delete-medicine]");

    if (editButton) {
        const id = editButton.dataset.editMedicine;

        try {
            const result = await apiRequest(`${API}/medicines/${id}`);
            const medicine = result.data || result.medicine || result;

            $("edit-medicine-id").value = medicine.medicine_id;
            $("med-brand").value = medicine.brand_name || "";
            $("med-generic").value = medicine.generic_name || "";
            $("med-category").value = medicine.category_id || "";
            $("med-manufacturer").value = medicine.manufacturer_id || "";
            $("med-form").value = medicine.dosage_form || "";
            $("med-strength").value = medicine.strength || "";
            $("med-route").value = medicine.administration_route || "";
            $("med-classification").value =
                medicine.prescription_classification || "PRESCRIPTION_ONLY";
            $("med-barcode").value = medicine.barcode_upc || "";
            $("med-ndc").value = medicine.ndc_number || "";

            $("save-medicine").textContent = "Update Medicine";

            $("medicine-form").scrollIntoView({
                behavior: "smooth",
                block: "center"
            });

        } catch (error) {
            showNotification(error.message);
        }
    }

    if (deleteButton) {
        const id = deleteButton.dataset.deleteMedicine;

        if (!confirm("Deactivate this medicine? Historical records will be retained.")) {
            return;
        }

        deleteButton.disabled = true;

        try {
            const result = await apiRequest(`${API}/medicines/${id}`, {
                method: "DELETE"
            });

            showNotification(result.message || "Medicine deactivated.");

            resetMedicineForm();

            await Promise.all([
                loadAdminMedicines(),
                loadMedicines(),
                loadDashboard()
            ]);

        } catch (error) {
            showNotification(error.message);
            deleteButton.disabled = false;
        }
    }
});

$("cancel-medicine-edit").addEventListener("click", resetMedicineForm);

$("refresh-users").addEventListener("click", loadAdminUsers);

/* =========================================================
   PAGE NAVIGATION
========================================================= */

function showPage(page) {
    if (page === "admin" && currentUser?.role !== "ADMIN") {
        showNotification("Admin access required.");
        return;
    }

    document.querySelectorAll(".page").forEach(section => {
        section.classList.remove("active");
    });

    document.querySelectorAll(".nav-item").forEach(item => {
        item.classList.remove("active");
    });

    const section = $(`${page}-page`);

    if (!section) return;

    section.classList.add("active");

    const nav = document.querySelector(
        `[data-page="${page}"].nav-item`
    );

    if (nav) nav.classList.add("active");

    const titles = {
        dashboard: "Dashboard Overview",
        medicines: "Medicine Catalogue",
        safety: "Safety & Interactions",
        recalls: "Recall Monitoring",
        batches: "Batch Management",
        profile: "My Profile",
        admin: "Admin Management"
    };

    const title = titles[page] || page;

    $("page-title").textContent = title;
    $("breadcrumb").textContent = title;

    if (page === "medicines") loadMedicines();
    if (page === "recalls") loadRecalls();
    if (page === "batches") loadBatches();

    if (page === "admin") {
        loadAdminUsers();
        loadAdminMedicines();
    }

    if (page === "profile" && currentUser) {
        $("profile-details").innerHTML = `
            <p><strong>Name:</strong>
                ${escapeHTML(currentUser.full_name)}
            </p>
            <p><strong>Username:</strong>
                ${escapeHTML(currentUser.username)}
            </p>
            <p><strong>Email:</strong>
                ${escapeHTML(currentUser.email)}
            </p>
            <p><strong>Role:</strong>
                ${escapeHTML(currentUser.role)}
            </p>
        `;
    }
}

/* =========================================================
   EVENT LISTENERS
========================================================= */

document.querySelectorAll("[data-page]").forEach(item => {
    item.addEventListener("click", event => {
        event.preventDefault();
        showPage(item.dataset.page);
    });
});

$("medicine-search").addEventListener("input", event => {
    clearTimeout(medicineSearchTimer);

    medicineSearchTimer = setTimeout(() => {
        loadMedicines(event.target.value.trim());
    }, 300);
});

$("safety-search").addEventListener("click", loadSafety);

$("logout-btn").addEventListener("click", async () => {
    try {
        await apiRequest(`${API}/auth/logout`, {
            method: "POST"
        });
    } catch (error) {
        console.error(error);
    }

    currentUser = null;
    showLogin();
});

/* =========================================================
   START APPLICATION
========================================================= */

initializeApp();

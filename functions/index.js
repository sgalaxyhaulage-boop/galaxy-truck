const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const axios = require("axios");

initializeApp();
const db = getFirestore();

const WIXTRAC_API = "https://point.wixtrac.com/wialon/ajax.html";
const WIXTRAC_USER = "galaxy";
const WIXTRAC_PASS = "Gora6016";

async function wixtracLogin() {
  const params = new URLSearchParams({
    svc: "core/login",
    params: JSON.stringify({ user: WIXTRAC_USER, password: WIXTRAC_PASS, token: "" }),
  });
  const res = await axios.post(WIXTRAC_API, params.toString(), {
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    timeout: 15000,
  });
  if (res.data.error) throw new Error("WixTrac login failed: " + res.data.error);
  return res.data.eid;
}

async function fetchUnits(eid) {
  const params = new URLSearchParams({
    svc: "core/search_items",
    params: JSON.stringify({
      spec: { itemsType: "avl_unit", propName: "sys_name", propValueMask: "*", sortType: "sys_name" },
      force: 1,
      flags: 1025,
      from: 0,
      count: 500,
    }),
    sid: eid,
  });
  const res = await axios.post(WIXTRAC_API, params.toString(), {
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    timeout: 30000,
  });
  if (res.data.error) throw new Error("WixTrac search_items failed: " + res.data.error);
  return res.data.items || [];
}

async function wixtracLogout(eid) {
  try {
    const params = new URLSearchParams({ svc: "core/logout", sid: eid });
    await axios.post(WIXTRAC_API, params.toString(), {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      timeout: 5000,
    });
  } catch (_) {}
}

async function syncGPS() {
  let eid = null;
  try {
    eid = await wixtracLogin();
    const units = await fetchUnits(eid);
    const batch = db.batch();
    let updated = 0;
    for (const unit of units) {
      if (!unit.pos) continue;
      const docRef = db.collection("truck_locations").doc(String(unit.id));
      batch.set(docRef, {
        unitId: unit.id,
        name: unit.nm || "Unit " + unit.id,
        lat: unit.pos.y,
        lng: unit.pos.x,
        speed: unit.pos.s ?? 0,
        course: unit.pos.c ?? 0,
        timestamp: unit.pos.t,
        updatedAt: FieldValue.serverTimestamp(),
      });
      updated++;
    }
    await batch.commit();
    console.log("GPS sync: " + updated + "/" + units.length + " units written");
    return { updated, total: units.length };
  } finally {
    if (eid) await wixtracLogout(eid);
  }
}

// Runs every 1 minute — requires Firebase Blaze plan
exports.syncGPSScheduled = onSchedule("every 1 minutes", async () => {
  await syncGPS();
});

// HTTP trigger for manual/test syncs
exports.syncGPSHttp = onRequest(async (req, res) => {
  try {
    const result = await syncGPS();
    res.json({ ok: true, ...result });
  } catch (err) {
    console.error("GPS sync error:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

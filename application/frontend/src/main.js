import "./style.css";

const $ = (id) => document.getElementById(id);
const money = new Intl.NumberFormat(undefined, { style: "currency", currency: "USD" });
const count = new Intl.NumberFormat();

async function api(path, options = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    const detail = Array.isArray(body.detail) ? body.detail[0]?.msg : body.detail;
    throw new Error(detail || `Request failed with ${res.status}`);
  }
  return res.status === 204 ? null : res.json();
}

function say(text, isError = false) {
  const el = $("msg");
  el.textContent = text;
  el.classList.toggle("error", isError);
}

function row(item) {
  const tr = document.createElement("tr");
  if (item.quantity === 0) tr.className = "out";
  else if (item.low_stock) tr.className = "low";

  const value = Number(item.unit_price) * item.quantity;
  tr.innerHTML = `
    <td class="sku"></td>
    <td class="name"></td>
    <td class="num qty">
      <button class="step" data-d="-1" aria-label="Remove one">−</button>
      <span class="q"></span>
      <button class="step" data-d="1" aria-label="Add one">+</button>
    </td>
    <td class="num"></td>
    <td class="num"></td>
    <td class="num"><button class="del">Delete</button></td>`;
  tr.querySelector(".sku").textContent = item.sku;
  tr.querySelector(".name").textContent = item.name;
  tr.querySelector(".q").textContent = count.format(item.quantity);
  tr.children[3].textContent = count.format(item.reorder_level);
  tr.children[4].textContent = money.format(value);

  tr.querySelectorAll(".step").forEach((b) =>
    b.addEventListener("click", async () => {
      const quantity = Math.max(0, item.quantity + Number(b.dataset.d));
      try {
        await api(`/items/${item.id}`, { method: "PUT", body: JSON.stringify({ quantity }) });
        await refresh();
      } catch (e) {
        say(e.message, true);
      }
    }),
  );
  tr.querySelector(".del").addEventListener("click", async () => {
    if (!confirm(`Delete ${item.sku}?`)) return;
    try {
      await api(`/items/${item.id}`, { method: "DELETE" });
      say(`Deleted ${item.sku}.`);
      await refresh();
    } catch (e) {
      say(e.message, true);
    }
  });
  return tr;
}

async function refresh() {
  const onlyLow = $("only-low").checked;
  const [items, stats] = await Promise.all([
    api(`/items${onlyLow ? "?low_stock=true" : ""}`),
    api("/items/stats"),
  ]);
  $("rows").replaceChildren(...items.map(row));
  $("empty").hidden = items.length > 0;
  $("s-skus").textContent = count.format(stats.total_skus);
  $("s-units").textContent = count.format(stats.total_units);
  $("s-low").textContent = count.format(stats.low_stock);
  $("s-value").textContent = money.format(Number(stats.inventory_value));
}

$("add").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const data = Object.fromEntries(new FormData(ev.target));
  data.quantity = Number(data.quantity);
  data.reorder_level = Number(data.reorder_level);
  try {
    const created = await api("/items", { method: "POST", body: JSON.stringify(data) });
    ev.target.reset();
    say(`Added ${created.sku}.`);
    await refresh();
  } catch (e) {
    say(e.message, true);
  }
});
$("only-low").addEventListener("change", () => refresh().catch((e) => say(e.message, true)));

async function boot() {
  try {
    const info = await api("/info");
    $("build").textContent = `${info.environment} · build ${String(info.version).slice(0, 7)}`;
    await refresh();
  } catch (e) {
    $("build").textContent = "API unreachable";
    say(`Can't reach the inventory API (${e.message}). Check that the backend is running.`, true);
  }
}
boot();

const BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000/api/v1";

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `HTTP ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const linksApi = {
  list: () => request("/links/"),
  create: (data) => request("/links/", { method: "POST", body: JSON.stringify(data) }),
  update: (id, data) => request(`/links/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  remove: (id) => request(`/links/${id}`, { method: "DELETE" }),
};

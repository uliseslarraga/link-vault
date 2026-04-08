import { useState, useEffect, useCallback } from "react";
import { linksApi } from "../api/links";

export function useLinks() {
  const [links, setLinks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchLinks = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await linksApi.list();
      setLinks(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchLinks(); }, [fetchLinks]);

  const addLink = async (payload) => {
    const created = await linksApi.create(payload);
    setLinks((prev) => [created, ...prev]);
    return created;
  };

  const removeLink = async (id) => {
    await linksApi.remove(id);
    setLinks((prev) => prev.filter((l) => l.id !== id));
  };

  return { links, loading, error, addLink, removeLink, refresh: fetchLinks };
}

import { useState } from "react";
import { useLinks } from "./hooks/useLinks";
import "./index.css";

function AddLinkForm({ onAdd }) {
  const [url, setUrl] = useState("");
  const [title, setTitle] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [err, setErr] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!url.trim()) return;
    try {
      setSubmitting(true);
      setErr(null);
      await onAdd({ url: url.trim(), title: title.trim() || null, note: note.trim() || null });
      setUrl(""); setTitle(""); setNote("");
    } catch (e) {
      setErr(e.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form className="add-form" onSubmit={handleSubmit}>
      <div className="form-row">
        <input
          className="input"
          type="url"
          placeholder="https://..."
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          required
        />
        <input
          className="input"
          type="text"
          placeholder="Title (optional)"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
      </div>
      <div className="form-row">
        <input
          className="input input--wide"
          type="text"
          placeholder="Note (optional)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
        <button className="btn btn--primary" type="submit" disabled={submitting}>
          {submitting ? "Saving…" : "Save Link"}
        </button>
      </div>
      {err && <p className="error">{err}</p>}
    </form>
  );
}

function LinkCard({ link, onDelete }) {
  const domain = (() => {
    try { return new URL(link.url).hostname; } catch { return link.url; }
  })();

  return (
    <article className="card">
      {link.screenshot_url && (
        <img className="card__thumb" src={link.screenshot_url} alt={link.title || domain} />
      )}
      <div className="card__body">
        <a className="card__url" href={link.url} target="_blank" rel="noopener noreferrer">
          {link.title || domain}
        </a>
        <span className="card__domain">{domain}</span>
        {link.note && <p className="card__note">{link.note}</p>}
        <time className="card__time">
          {new Date(link.created_at).toLocaleDateString()}
        </time>
      </div>
      <button className="card__delete" onClick={() => onDelete(link.id)} title="Delete">✕</button>
    </article>
  );
}

export default function App() {
  const { links, loading, error, addLink, removeLink } = useLinks();

  return (
    <div className="app">
      <header className="header">
        <h1 className="header__title">Link Vault</h1>
        <p className="header__sub">{links.length} saved</p>
      </header>

      <main className="main">
        <AddLinkForm onAdd={addLink} />

        {loading && <p className="state-msg">Loading…</p>}
        {error && <p className="state-msg state-msg--error">Error: {error}</p>}
        {!loading && links.length === 0 && (
          <p className="state-msg">No links yet. Save your first one above.</p>
        )}

        <section className="grid">
          {links.map((l) => (
            <LinkCard key={l.id} link={l} onDelete={removeLink} />
          ))}
        </section>
      </main>
    </div>
  );
}

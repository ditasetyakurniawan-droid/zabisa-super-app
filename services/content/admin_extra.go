package main

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
)

type contentIn struct {
	Type      string `json:"type"`
	Title     string `json:"title"`
	Slug      string `json:"slug"`
	Summary   string `json:"summary"`
	Body      string `json:"body"`
	ImageURL  string `json:"image_url"`
	Published bool   `json:"published"`
}

func (a *app) listKajianAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,title,slug,description,speaker,start_at,end_at,location,map_url,live_url,poster_url,status,published,created_at,updated_at FROM kajian ORDER BY start_at DESC LIMIT 300`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load kajian")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, title, slug, desc, status string
		var speaker, location, mapURL, liveURL, posterURL sql.NullString
		var start, created, updated time.Time
		var end sql.NullTime
		var published bool
		if rows.Scan(&id, &title, &slug, &desc, &speaker, &start, &end, &location, &mapURL, &liveURL, &posterURL, &status, &published, &created, &updated) == nil {
			out = append(out, map[string]any{"id": id, "title": title, "slug": slug, "description": desc, "speaker": speaker.String, "start_at": start, "end_at": database.NullableTime(end), "location": location.String, "map_url": mapURL.String, "live_url": liveURL.String, "poster_url": posterURL.String, "status": status, "published": published, "created_at": created, "updated_at": updated})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) updateKajian(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in kajianIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Slug) == "" || strings.TrimSpace(in.Description) == "" || in.StartAt.IsZero() {
		httpx.Fail(w, r, 400, "VALIDATION", "Title, slug, description and start_at are required")
		return
	}
	status := "UPCOMING"
	if in.StartAt.Before(time.Now().UTC()) {
		status = "ONGOING"
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update kajian")
		return
	}
	defer tx.Rollback()
	var beforeTitle, beforeSlug, beforeStatus string
	var wasPublished bool
	if err = tx.QueryRowContext(r.Context(), `SELECT title,slug,status,published FROM kajian WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeTitle, &beforeSlug, &beforeStatus, &wasPublished); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Kajian not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load kajian")
		return
	}
	_, err = tx.ExecContext(r.Context(), `UPDATE kajian SET title=?,slug=?,description=?,speaker=?,start_at=?,end_at=?,location=?,map_url=?,live_url=?,poster_url=?,status=?,published=? WHERE id=?`, in.Title, in.Slug, in.Description, null(in.Speaker), in.StartAt, in.EndAt, null(in.Location), null(in.MapURL), null(in.LiveURL), null(in.PosterURL), status, in.Published, p["id"])
	if err == nil && !wasPublished && in.Published {
		err = outbox.Add(r.Context(), tx, "KajianPublished", map[string]any{"kajian_id": p["id"], "title": in.Title, "deep_link": "zabisa://kajian/" + p["id"]})
	}
	if err == nil {
		before := map[string]any{"title": beforeTitle, "slug": beforeSlug, "status": beforeStatus, "published": wasPublished}
		after := map[string]any{"title": in.Title, "slug": in.Slug, "status": status, "published": in.Published}
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "KAJIAN_UPDATED", "kajian", p["id"], before, after))
	}
	if err != nil {
		httpx.Fail(w, r, 409, "UPDATE_FAILED", "Could not update kajian")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update kajian")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": p["id"], "status": status, "published": in.Published})
}

func (a *app) createContent(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
	var in contentIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Type = strings.ToUpper(strings.TrimSpace(in.Type))
	if in.Type == "" || strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Slug) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "type, title and slug are required")
		return
	}
	allowed := map[string]bool{"PROFILE": true, "PROGRAM": true, "NEWS": true, "ARTICLE": true, "ANNOUNCEMENT": true, "EMERGENCY": true, "GALLERY": true, "BANNER": true}
	if !allowed[in.Type] {
		httpx.Fail(w, r, 400, "VALIDATION", "Unsupported content type")
		return
	}
	id := httpx.NewID()
	var pub any
	if in.Published {
		pub = time.Now().UTC()
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create content")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO contents(id,type,title,slug,summary,body,image_url,published,published_at) VALUES(?,?,?,?,?,?,?,?,?)`, id, in.Type, in.Title, in.Slug, null(in.Summary), null(in.Body), null(in.ImageURL), in.Published, pub); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create content; slug may already exist")
		return
	}
	after := map[string]any{"type": in.Type, "title": strings.TrimSpace(in.Title), "slug": strings.TrimSpace(in.Slug), "published": in.Published}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CONTENT_CREATED", "content", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit content creation")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create content")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}

func (a *app) updateContent(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in contentIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Type = strings.ToUpper(strings.TrimSpace(in.Type))
	if in.Type == "" || strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Slug) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "type, title and slug are required")
		return
	}
	allowed := map[string]bool{"PROFILE": true, "PROGRAM": true, "NEWS": true, "ARTICLE": true, "ANNOUNCEMENT": true, "EMERGENCY": true, "GALLERY": true, "BANNER": true}
	if !allowed[in.Type] {
		httpx.Fail(w, r, 400, "VALIDATION", "Unsupported content type")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update content")
		return
	}
	defer tx.Rollback()
	var beforeType, beforeTitle, beforeSlug string
	var beforePublished bool
	if err = tx.QueryRowContext(r.Context(), `SELECT type,title,slug,published FROM contents WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeType, &beforeTitle, &beforeSlug, &beforePublished); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Content not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not validate content")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE contents SET type=?,title=?,slug=?,summary=?,body=?,image_url=?,published=?,published_at=CASE WHEN ? THEN COALESCE(published_at,UTC_TIMESTAMP(6)) ELSE NULL END WHERE id=?`, in.Type, in.Title, in.Slug, null(in.Summary), null(in.Body), null(in.ImageURL), in.Published, in.Published, p["id"]); err != nil {
		httpx.Fail(w, r, 409, "UPDATE_FAILED", "Could not update content; slug may already exist")
		return
	}
	before := map[string]any{"type": beforeType, "title": beforeTitle, "slug": beforeSlug, "published": beforePublished}
	after := map[string]any{"type": in.Type, "title": strings.TrimSpace(in.Title), "slug": strings.TrimSpace(in.Slug), "published": in.Published}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CONTENT_UPDATED", "content", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit content update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update content")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": p["id"], "published": in.Published})
}

func (a *app) listContentAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	typ := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("type")))
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,type,title,slug,summary,body,image_url,published,published_at,created_at FROM contents WHERE (?='' OR type=?) ORDER BY created_at DESC LIMIT 500`, typ, typ)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load content")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, t, title, slug string
		var summary, body, image sql.NullString
		var published bool
		var pub sql.NullTime
		var created time.Time
		if rows.Scan(&id, &t, &title, &slug, &summary, &body, &image, &published, &pub, &created) == nil {
			out = append(out, map[string]any{"id": id, "type": t, "title": title, "slug": slug, "summary": summary.String, "body": body.String, "image_url": image.String, "published": published, "published_at": database.NullableTime(pub), "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) getContent(w http.ResponseWriter, r *http.Request, p map[string]string) {
	var id, typ, title, slug string
	var summary, body, image sql.NullString
	var pub sql.NullTime
	err := a.db.QueryRowContext(r.Context(), `SELECT id,type,title,slug,summary,body,image_url,published_at FROM contents WHERE id=? AND published=TRUE`, p["id"]).Scan(&id, &typ, &title, &slug, &summary, &body, &image, &pub)
	if err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Content not found")
		return
	}
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load content")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": id, "type": typ, "title": title, "slug": slug, "summary": summary.String, "body": body.String, "image_url": image.String, "published_at": database.NullableTime(pub)})
}

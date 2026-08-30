package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

type Claims struct {
	Sub       string `json:"sub"`
	Role      string `json:"role"`
	Exp       int64  `json:"exp"`
	Iat       int64  `json:"iat"`
	SessionID string `json:"sid"`
}

var ErrInvalidToken = errors.New("invalid token")

func Sign(key string, c Claims) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	bodyBytes, err := json.Marshal(c)
	if err != nil {
		return "", err
	}
	body := base64.RawURLEncoding.EncodeToString(bodyBytes)
	msg := header + "." + body
	mac := hmac.New(sha256.New, []byte(key))
	_, _ = mac.Write([]byte(msg))
	sig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return msg + "." + sig, nil
}
func Verify(key, token string) (Claims, error) {
	var c Claims
	p := strings.Split(token, ".")
	if len(p) != 3 {
		return c, ErrInvalidToken
	}
	mac := hmac.New(sha256.New, []byte(key))
	_, _ = mac.Write([]byte(p[0] + "." + p[1]))
	sig, err := base64.RawURLEncoding.DecodeString(p[2])
	if err != nil || !hmac.Equal(sig, mac.Sum(nil)) {
		return c, ErrInvalidToken
	}
	b, err := base64.RawURLEncoding.DecodeString(p[1])
	if err != nil || json.Unmarshal(b, &c) != nil || c.Sub == "" || c.Exp <= time.Now().Unix() {
		return Claims{}, ErrInvalidToken
	}
	return c, nil
}
func AccessClaims(userID, role, sessionID string, ttl time.Duration) Claims {
	now := time.Now().UTC()
	return Claims{Sub: userID, Role: role, SessionID: sessionID, Iat: now.Unix(), Exp: now.Add(ttl).Unix()}
}

"""Verify the existing Cloudflare login before consulting Directus roles.

No role cache or user directory lives here. Only signed human identity crosses
this boundary; service tokens and caller-supplied email headers grant no rights.
"""
from __future__ import annotations

import re

import jwt
from jwt import PyJWKClient


class IdentityDenied(ValueError):
    """Public-safe authentication failure; never include the bearer token."""


class AccessIdentity:
    def __init__(self, issuer: str, audience: str):
        # Configuration, never unverified token claims, determines the key URL.
        if not re.fullmatch(r"https://[a-zA-Z0-9-]+\.cloudflareaccess\.com", issuer):
            raise RuntimeError("A fixed Cloudflare team issuer is required")
        if not re.fullmatch(r"[a-f0-9]{64}", audience):
            raise RuntimeError("The exact My MSB application audience is required")
        self.issuer = issuer
        self.audience = audience
        # Cache only the JWKS, not identities or per-key objects indefinitely.
        # Unknown-key refresh has a cooldown to bound attacker-triggered fetches.
        self.keys = PyJWKClient(issuer + "/cdn-cgi/access/certs",
                               cache_keys=False, lifespan=300, timeout=5,
                               cooldown_duration=30)

    def email(self, token: str) -> str:
        if not isinstance(token, str) or not token or len(token) > 16384:
            raise IdentityDenied("Cloudflare login required")
        try:
            header = jwt.get_unverified_header(token)
            if header.get("alg") != "RS256" or not isinstance(header.get("kid"), str) or not header["kid"]:
                raise IdentityDenied("Invalid Cloudflare login")
            key = self.keys.get_signing_key_from_jwt(token)
            claims = jwt.decode(token, key.key, algorithms=["RS256"],
                                issuer=self.issuer, audience=self.audience,
                                options={"require": ["exp", "iat", "iss", "aud", "sub", "email"]})
            email = claims["email"]
            if (claims.get("type") != "app" or not claims["sub"]
                    or not isinstance(email, str) or len(email) > 254
                    or not re.fullmatch(r"[^\s@]+@sheboyganlights\.org", email, re.IGNORECASE)):
                raise IdentityDenied("Human MSB login required")
            return email.lower()
        except (jwt.PyJWTError, ValueError, TypeError, KeyError, OSError) as exc:
            # A key-service outage must never enable the old header-only path.
            raise IdentityDenied("Cloudflare login could not be verified") from exc

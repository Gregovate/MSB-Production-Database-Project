"""Real RSA signature checks with local keys; no Cloudflare/Production contact."""
import json
import time
from functools import lru_cache
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from access_identity import AccessIdentity, IdentityDenied

ISSUER = "https://test-team.cloudflareaccess.com"
AUDIENCE = "a" * 64


@lru_cache
def private_key():
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


def jwks():
    key = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(private_key().public_key()))
    return {"keys": [{**key, "kid": "test-key", "use": "sig", "alg": "RS256"}]}


def signed_token(**overrides):
    now = int(time.time())
    claims = {"iss": ISSUER, "aud": [AUDIENCE], "sub": "human-id",
              "iat": now, "exp": now + 300, "type": "app",
              "email": "crew@sheboyganlights.org"}
    claims.update(overrides)
    return jwt.encode(claims, private_key(), algorithm="RS256", headers={"kid": "test-key"})


@pytest.fixture
def verifier(monkeypatch):
    verifier = AccessIdentity(ISSUER, AUDIENCE)
    monkeypatch.setattr(verifier.keys, "fetch_data", jwks)
    return verifier


def test_signed_human_identity(verifier):
    assert verifier.email(signed_token(email="Crew@sheboyganlights.org")) == "crew@sheboyganlights.org"


@pytest.mark.parametrize("claims", [
    {"iss": "https://attacker.cloudflareaccess.com"}, {"aud": ["b" * 64]},
    {"exp": 1}, {"iat": int(time.time()) + 600}, {"nbf": int(time.time()) + 600},
    {"sub": ""}, {"email": "attacker@example.com"}, {"email": None},
    {"type": "service"}, {"type": None},
])
def test_invalid_claims_denied(verifier, claims):
    with pytest.raises(IdentityDenied):
        verifier.email(signed_token(**claims))


@pytest.mark.parametrize("claim", ["exp", "iat", "iss", "aud", "sub", "email"])
def test_required_claims(verifier, claim):
    payload = jwt.decode(signed_token(), options={"verify_signature": False})
    payload.pop(claim)
    token = jwt.encode(payload, private_key(), algorithm="RS256", headers={"kid": "test-key"})
    with pytest.raises(IdentityDenied):
        verifier.email(token)


@pytest.mark.parametrize("token", ["", "bad", "x" * 16385,
    jwt.encode({"email": "crew@sheboyganlights.org"}, "", algorithm="none"),
    jwt.encode({"email": "crew@sheboyganlights.org"}, "a" * 64, algorithm="HS256", headers={"kid": "test-key"}),
])
def test_missing_malformed_unsigned_and_wrong_algorithm(verifier, token):
    with pytest.raises(IdentityDenied):
        verifier.email(token)


def test_attacker_signature_denied(verifier):
    payload = jwt.decode(signed_token(), options={"verify_signature": False})
    attacker = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    token = jwt.encode(payload, attacker, algorithm="RS256", headers={"kid": "test-key"})
    with pytest.raises(IdentityDenied):
        verifier.email(token)


def test_unknown_key_denied(verifier):
    payload = jwt.decode(signed_token(), options={"verify_signature": False})
    token = jwt.encode(payload, private_key(), algorithm="RS256", headers={"kid": "unknown"})
    with pytest.raises(IdentityDenied):
        verifier.email(token)


def test_key_outage_denied(verifier, monkeypatch):
    def outage(*args, **kwargs):
        raise jwt.PyJWKClientConnectionError("unavailable")
    monkeypatch.setattr(verifier.keys, "fetch_data", outage)
    with pytest.raises(IdentityDenied):
        verifier.email(signed_token())


def test_rotated_key_refresh(verifier, monkeypatch):
    old = jwks()
    old["keys"][0]["kid"] = "old-key"
    verifier.keys.jwk_set_cache.put(old)
    assert verifier.email(signed_token()) == "crew@sheboyganlights.org"


@pytest.mark.parametrize("issuer,audience", [("http://test.cloudflareaccess.com", AUDIENCE),
    (ISSUER + "/evil", AUDIENCE), ("https://attacker.example", AUDIENCE), (ISSUER, "")])
def test_invalid_configuration_fails_startup(issuer, audience):
    with pytest.raises(RuntimeError):
        AccessIdentity(issuer, audience)


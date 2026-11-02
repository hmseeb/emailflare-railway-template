#!/bin/sh
# Real user journey against a live deploy: dashboard UI served, bad login refused,
# login, create a test key, send with it, read it back from the Test Mailbox.
# Usage: test/journey.sh <https://base-url> <ADMIN_TOKEN>
set -eu
BASE=$1 TOKEN=$2 JAR=$(mktemp) STAMP=$(date +%s)
trap 'rm -f "$JAR"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

curl -sf "$BASE/health" | grep -q '"ok":true' || fail health
curl -sf "$BASE/" | grep -qi '<div id="root"\|<script' || fail "dashboard html"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d '{"token":"wrong-wrong-wrong-wrong-wrong-wrong"}')" = 401 ] || fail "bad token accepted"
curl -sf -c "$JAR" -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"token\":\"$TOKEN\"}" | grep -q '"ok":true' || fail login
curl -sf -b "$JAR" "$BASE/api/auth/me" | grep -q '"ok":true' || fail "session cookie"

KEY=$(curl -sf -b "$JAR" -X POST "$BASE/api/keys" -H 'Content-Type: application/json' \
  -d "{\"name\":\"journey-$STAMP\",\"type\":\"test\",\"scope\":\"global\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["key"])')
case $KEY in eftest_*) ;; *) fail "key create";; esac

[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/v1/send" -H 'Content-Type: application/json' -d '{}')" = 401 ] || fail "send without key not refused"
curl -sf -X POST "$BASE/v1/send" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d "{\"from\":\"hello@example.com\",\"to\":\"you@example.com\",\"subject\":\"journey $STAMP\",\"text\":\"It works\"}" >/dev/null || fail send
curl -sf -b "$JAR" "$BASE/api/test-emails" | grep -q "journey $STAMP" || fail "message not in Test Mailbox"
echo "PASS: login, test key, send, Test Mailbox ($STAMP)"

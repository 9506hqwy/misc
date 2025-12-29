# フロー

## Authorization Code Grant

Authorization Code Grant フローを記載する。

- クライアント種別は confidential
- アクセストークンの検証はイントロスペクション

![Authorization Code Grant フロー](./images/oauth-flow-authorization-code-grant.png)

Keycloak を開発モードで起動する。

```sh
podman run \
    --rm \
    -d \
    -p 8080:8080 \
    -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
    -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
    keycloak/keycloak \
    start-dev
```

`http://127.0.0.1:8080/admin/` に接続して `admin` でログインする。

![Authorization Code Grant 管理者ログイン](./images/oauth-flow-authorization-code-grant-keycloak-admin-login.png)

レルムを作成する。

![Authorization Code Grant レルム作成](./images/oauth-flow-authorization-code-grant-keycloak-admin-create-realm.png)

ユーザを作成する。

![Authorization Code Grant ユーザ作成](./images/oauth-flow-authorization-code-grant-keycloak-admin-create-user.png)

パスワードを設定する。

![Authorization Code Grant パスワード設定](./images/oauth-flow-authorization-code-grant-keycloak-admin-set-passwordpng.png)

`http://127.0.0.1:8080/realms/home.local/account/` に接続して `administrator` でログインする。

![Authorization Code Grant ログイン](./images/oauth-flow-authorization-code-grant-keycloak-realm-login.png)

クライアントを登録する。

![Authorization Code Grant クライアント作成01](./images/oauth-flow-authorization-code-grant-keycloak-admin-create-client-01.png)

![Authorization Code Grant クライアント作成02](./images/oauth-flow-authorization-code-grant-keycloak-admin-create-client-02.png)

![Authorization Code Grant クライアント作成03](./images/oauth-flow-authorization-code-grant-keycloak-admin-create-client-03.png)

認可コードを要求する URL を生成する。

```sh
AUTHZ_TYPE=code
CLIENT_ID=authz-code-grant
REDIRECT_URI=$(echo -n "http://myapp.home.local/" | jq -rR '@uri')
STATE=abc
CODE_VERIFIER=$(cat /dev/random | tr -dc 'a-f0-9' | head -c 64)
CODE_CHALLENGE=$(echo -n "${CODE_VERIFIER}" | openssl dgst -sha256 -binary | base64 -w 0 | tr '+/' '-_' | tr -d '=')
CODE_CHALLENGE_METHOD=S256

echo "http://169.254.10.67:8080/realms/home.local/protocol/openid-connect/auth?response_type=${AUTHZ_TYPE}&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=${CODE_CHALLENGE_METHOD}"
```

```text
http://169.254.10.67:8080/realms/home.local/protocol/openid-connect/auth?response_type=code&client_id=authz-code-grant&redirect_uri=http%3A%2F%2Fmyapp.home.local%2F&state=abc&code_challenge=BDLhkeFW76oAhZb7kkQdsfejO7wknNRzuxbJyYLXg6M&code_challenge_method=S256
```

上記の URL へ接続後に `administrator` でログインする。

![Authorization Code Grant 認可承認](./images/oauth-flow-authorization-code-grant-keycloak-grant-login.png)

レスポンスの `Location` ヘッダに下記の設定される。

```text
http://myapp.home.local/?state=abc&session_state=d4ea6dfb-d9bf-808f-2990-fbe93a05e18b&iss=http%3A%2F%2F169.254.10.67%3A8080%2Frealms%2Fhome.local&code=3b69d21b-9e2e-a45b-805e-0712c9f3ff70.d4ea6dfb-d9bf-808f-2990-fbe93a05e18b.8fd65429-d331-4be8-b79a-458eb27a1ab2
```

| クエリ        | 値                                                                                                             |
| :------------ | :------------------------------------------------------------------------------------------------------------- |
| state         | abc                                                                                                            |
| session_state | d4ea6dfb-d9bf-808f-2990-fbe93a05e18b                                                                           |
| iss           | http:://169.254.10.67:8080/realms/home.local                                                                   |
| code          | 3b69d21b-9e2e-a45b-805e-0712c9f3ff70.d4ea6dfb-d9bf-808f-2990-fbe93a05e18b.8fd65429-d331-4be8-b79a-458eb27a1ab2 |

アクセスコードを要求する。

```sh
GRANT_TYPE=authorization_code
CLIENT_SECRET=qDVy5zhZ5acy0VYn6JsN3N683m1ua1DI
REDIRECT_URI=http://myapp.home.local/
CODE=3b69d21b-9e2e-a45b-805e-0712c9f3ff70.d4ea6dfb-d9bf-808f-2990-fbe93a05e18b.8fd65429-d331-4be8-b79a-458eb27a1ab2

curl -sS \
    -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -X POST \
    -d "grant_type=${GRANT_TYPE}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code=${CODE}" \
    -d "code_verifier=${CODE_VERIFIER}" \
    "http://127.0.0.1:8080/realms/home.local/protocol/openid-connect/token" | jq
```

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI1WDVBcTFGOG9mOFJiSjBUZWNwUTIzV2dIc3hpUm5xZzVNYVR0Tlg3bkFJIn0.eyJleHAiOjE3NjY5MTEwNzMsImlhdCI6MTc2NjkxMDc3MywiYXV0aF90aW1lIjoxNzY2OTAyOTc5LCJqdGkiOiJvbnJ0YWM6YjlkOGU4NTAtMDE3OS03MjRiLTE2ZjktY2RkOTk5ZjEwOWRjIiwiaXNzIjoiaHR0cDovLzE2OS4yNTQuMTAuNjc6ODA4MC9yZWFsbXMvaG9tZS5sb2NhbCIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJiZDc5MDI1OC04MmM5LTQxYmQtYWVjYy05MDQ4OGFlYzJmNzgiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJhdXRoei1jb2RlLWdyYW50Iiwic2lkIjoiZDRlYTZkZmItZDliZi04MDhmLTI5OTAtZmJlOTNhMDVlMThiIiwiYWNyIjoiMCIsImFsbG93ZWQtb3JpZ2lucyI6WyJodHRwOi8vbXlhcHAuaG9tZS5sb2NhbCJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJkZWZhdWx0LXJvbGVzLWhvbWUubG9jYWwiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoiZW1haWwgcHJvZmlsZSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwibmFtZSI6ImFkbWluIGFkbWluIiwicHJlZmVycmVkX3VzZXJuYW1lIjoiYWRtaW5pc3RyYXRvciIsImdpdmVuX25hbWUiOiJhZG1pbiIsImZhbWlseV9uYW1lIjoiYWRtaW4iLCJlbWFpbCI6ImFkbWluaXN0cmF0b3JAaG9tZS5sb2NhbCJ9.NKqkBSPhO3xUqplqubUDjY-VtrSqL_6OR7wcTQ_DivhKdGtW0W2z54hf7Gtq8Krd2OaJWbWKPpxqqYtHt58hYgnVT5v02whFGyT9169_hHEvkbHCpUR-V_CeQs8j-YfDNzY3hxyNMG_pZSOXytUZSoa8jVY3Sxm2H4JLJMYyFLAOihL46q_6wGYZxP2HoJpl3NmJpSR8h6AX7NYQmRCAsOfrJuWokQcwwPBYjY0SkU_UzBsbJQ2xU0P3dX86lrO6D2kOZilU381O4IM777YbqaHIELf5DYu3Jg3uMEhNv7XOAx1e1KVQvUfyvr_DUmfoFjB5AkQ1oc9Wh3dlPxyBVQ",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzUxMiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIyYTE1OTU3NS02NDIxLTRkY2UtOWRmNC02NzM3ZWNjZjdjMzMifQ.eyJleHAiOjE3NjY5MTI1NzMsImlhdCI6MTc2NjkxMDc3MywianRpIjoiNjRmYjQ4ZmMtMjU0Ny04Mjc3LWFiMmItZDRmMzAzNDlkNDE3IiwiaXNzIjoiaHR0cDovLzE2OS4yNTQuMTAuNjc6ODA4MC9yZWFsbXMvaG9tZS5sb2NhbCIsImF1ZCI6Imh0dHA6Ly8xNjkuMjU0LjEwLjY3OjgwODAvcmVhbG1zL2hvbWUubG9jYWwiLCJzdWIiOiJiZDc5MDI1OC04MmM5LTQxYmQtYWVjYy05MDQ4OGFlYzJmNzgiLCJ0eXAiOiJSZWZyZXNoIiwiYXpwIjoiYXV0aHotY29kZS1ncmFudCIsInNpZCI6ImQ0ZWE2ZGZiLWQ5YmYtODA4Zi0yOTkwLWZiZTkzYTA1ZTE4YiIsInNjb3BlIjoiYmFzaWMgcm9sZXMgd2ViLW9yaWdpbnMgZW1haWwgcHJvZmlsZSBhY3IifQ.A90hUrReQaWqJwYxQyH33UOkmaCO35ckgw16R1-OP1PtM9_GHUQ4H2ss-IFCThifF8UNraNWOStLXFMBadfkFQ",
  "token_type": "Bearer",
  "not-before-policy": 0,
  "session_state": "d4ea6dfb-d9bf-808f-2990-fbe93a05e18b",
  "scope": "email profile"
}
```

トークンを検証する。URL は `iss` を使用する。

```sh
TOKEN="..."

curl -sS \
    -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -X POST \
    -d "token=${TOKEN}" \
    "http://169.254.10.67:8080/realms/home.local/protocol/openid-connect/token/introspect" | jq
```

```json
{
  "exp": 1766911646,
  "iat": 1766911346,
  "auth_time": 1766902979,
  "jti": "onrtac:c84eda21-1ca9-173e-d4a2-58e3af3631f4",
  "iss": "http://169.254.10.67:8080/realms/home.local",
  "aud": "account",
  "sub": "bd790258-82c9-41bd-aecc-90488aec2f78",
  "typ": "Bearer",
  "azp": "authz-code-grant",
  "sid": "d4ea6dfb-d9bf-808f-2990-fbe93a05e18b",
  "acr": "0",
  "allowed-origins": [
    "*"
  ],
  "realm_access": {
    "roles": [
      "offline_access",
      "default-roles-home.local",
      "uma_authorization"
    ]
  },
  "resource_access": {
    "account": {
      "roles": [
        "manage-account",
        "manage-account-links",
        "view-profile"
      ]
    }
  },
  "scope": "email profile",
  "email_verified": false,
  "name": "admin admin",
  "preferred_username": "administrator",
  "given_name": "admin",
  "family_name": "admin",
  "email": "administrator@home.local",
  "client_id": "authz-code-grant",
  "username": "administrator",
  "token_type": "Bearer",
  "active": true
}
```

トークンについては [Json Web Token](./jwt.md) を参照する。

## Implicit Grant

## Resource Owner Password Credentials Grant

## Client Credentials Grant

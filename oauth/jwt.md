# Json Web Token

Json Web Token (JWT) について記載する。

```text
<ヘッダ>.<ペイロード>.<署名>
```

ヘッダを参照する。

```sh
echo "eyJhbGciOiJSUzI1NiIsInR5cCIgOiA..." | base64 -d | jq
```

```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "5X5Aq1F8of8RbJ0TecpQ23WgHsxiRnqg5MaTtNX7nAI"
}
```

| パラメータ      | 値                                          | 説明                                                                                                                                       |
| :-------------- | :------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------- |
| alg (Algorithm) | RS256                                       | 署名アルゴリズム (RSASSA-PKCS1-v1_5:[PKCS #1: RSA Cryptography Specifications Version 2.2](https://datatracker.ietf.org/doc/html/rfc8017)) |
| typ (Type)      | JWT                                         | メディアタイプ                                                                                                                             |
| kid (Key ID)    | 5X5Aq1F8of8RbJ0TecpQ23WgHsxiRnqg5MaTtNX7nAI | 署名用の鍵を特定する情報                                                                                                                   |

ペイロードを参照する。

```sh
echo "eyJleHAiOjE3NjY5MTEwNzMsImlhdCI..." | base64 -d | jq
```

```json
{
  "exp": 1766911073,
  "iat": 1766910773,
  "auth_time": 1766902979,
  "jti": "onrtac:b9d8e850-0179-724b-16f9-cdd999f109dc",
  "iss": "http://169.254.10.67:8080/realms/home.local",
  "aud": "account",
  "sub": "bd790258-82c9-41bd-aecc-90488aec2f78",
  "typ": "Bearer",
  "azp": "authz-code-grant",
  "sid": "d4ea6dfb-d9bf-808f-2990-fbe93a05e18b",
  "acr": "0",
  "allowed-origins": [
    "http://myapp.home.local"
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
  "email": "administrator@home.local"
}
```

| パラメータ                         | 値                                          | 説明                                            |
| :--------------------------------- | :------------------------------------------ | :---------------------------------------------- |
| exp (Expiration Time)              | 1766911073                                  | トークンの有効期限(エポック秒数)                |
| iat (Issued At)                    | 1766910773                                  | トークンの発行時刻(エポック秒数)                |
| auth_time                          | 1766902979                                  | (OIDC) 認証時刻(エポック秒数)                   |
| jti (JWT ID)                       | onrtac:b9d8e850-0179-724b-16f9-cdd999f109dc | トークンの一意な識別子                          |
| iss (Issuer)                       | http://169.254.10.67:8080/realms/home.local | トークンの発行者                                |
| aud (Audience)                     | account                                     | トークンの受領者                                |
| sub (Subject)                      | bd790258-82c9-41bd-aecc-90488aec2f78        | トークンの承認者 (ユーザ `administrator` の ID) |
| typ (Type)                         | Bearer                                      | (Keycloak) トークンの種別                       |
| azp (Authorized Party)             | authz-code-grant                            | (OIDC) 認可されたクライアント                   |
| sid (Session ID)                   | d4ea6dfb-d9bf-808f-2990-fbe93a05e18b        | (Keycloak) セッションの一意な識別子             |
| acr (Authentication Context Class) | 0                                           | (OIDC) 認証処理の識別子                         |
| allowed-origins                    | -                                           | (Keycloak) Web origins                          |
| realm_access                       | -                                           | (Keycloak) Realm roles                          |
| resource_access                    | -                                           | (Keycloak) Client roles                         |
| scope                              | email profile                               | (OIDC) スコープ                                 |
| email_verified                     | false                                       | (OIDC) メールアドレスが検証済みかどうか         |
| name                               | admin admin                                 | (OIDC) 名前                                     |
| preferred_username                 | administrator                               | (OIDC) 優先名前                                 |
| given_name                         | admin                                       | (OIDC) 名                                       |
| family_name                        | admin                                       | (OIDC) 氏                                       |
| email                              | administrator@home.local                    | (OIDC) メールアドレス                           |

公開鍵を使用して署名を検証する。公開鍵は Keycloak の Realm settings から取得する。

```sh
PUBKEY="-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQ...\n-----END PUBLIC KEY-----"
HEADER_PAYLOAD="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2l..."
SIGNATURE="NKqkBSPhO3xUqplqubUDjY-VtrSqL_6OR7wcTQ_DivhK..."

echo -n "${HEADER_PAYLOAD}" | openssl dgst -sha256 -verify <(echo -e -n "${PUBKEY}") -signature <(echo -n "${SIGNATURE}" | tr '\-_' '+/' | base64 -d)
```

```text
Verified OK
```

証明書を使用して署名を検証する。証明書は jwks_uri から `kid` を使用して取得する。

```sh
CERT=$(curl -sS http://169.254.10.67:8080/realms/home.local/protocol/openid-connect/certs | jq -r '.keys[] | select(.kid == "5X5Aq1F8of8RbJ0TecpQ23WgHsxiRnqg5MaTtNX7nAI") | .x5c | first')
IFS= PUBKEY="$(openssl x509 -in <(echo -n "${CERT}" | base64 -d) -pubkey --nocert)"
HEADER_PAYLOAD="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2l..."
SIGNATURE="NKqkBSPhO3xUqplqubUDjY-VtrSqL_6OR7wcTQ_DivhK..."

echo -n "${HEADER_PAYLOAD}" | openssl dgst -sha256 -verify <(echo -n "${PUBKEY}") -signature <(echo -n "${SIGNATURE}" | tr '\-_' '+/' | base64 -d)
```

```text
Verified OK
```

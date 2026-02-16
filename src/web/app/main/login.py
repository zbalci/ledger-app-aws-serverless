from flask import session, redirect, url_for
from app.main import bp
from app.extensions import oauth
from app.auth.cognito import build_cognito_config

cfg = build_cognito_config()

oauth.register(
    name="oidc",
    authority=cfg["authority"],
    client_id=cfg["client_id"],
    client_secret=cfg["client_secret"],
    server_metadata_url=cfg["server_metadata_url"],
    client_kwargs={"scope": "email openid profile"},
)

# oauth.register(
#   name='oidc',
#   authority='https://cognito-idp.eu-north-1.amazonaws.com/eu-north-1_OcupftfB2',
#   client_id='14nn8j8mt9n5vc8dir9jqb6n77',
#   client_secret='eo1tl6ol1ogh196ud0o19c3ejaohd89b495o5mkmu0ltg300ovo',
#   server_metadata_url='https://cognito-idp.eu-north-1.amazonaws.com/eu-north-1_OcupftfB2/.well-known/openid-configuration',
#   client_kwargs={'scope': 'email openid profile'}
# )

@bp.route('/login')
def login():
    redirect_uri = f"https://{cfg['base_domain']}/authorize"
    return oauth.oidc.authorize_redirect(redirect_uri)

@bp.route("/authorize")
def authorize():

    token = oauth.oidc.authorize_access_token()

    session["access_token"] = token["access_token"]

    user = token["userinfo"]

    session["user"] = {
        "name": user.get("name"),
        "email": user.get("email"),
    }

    return redirect(url_for("main.index"))

@bp.route("/logout")
def logout():

    session.clear()

    logout_url = (
        f"{cfg['cognito_domain']}/logout"
        f"?client_id={cfg['client_id']}"
        f"&logout_uri=https://{cfg['base_domain']}"
    )

    return redirect(logout_url)
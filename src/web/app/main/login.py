from flask import session, redirect, url_for
from app.main import bp
from app.extensions import oauth

oauth.register(
  name='oidc',
  authority='https://cognito-idp.eu-north-1.amazonaws.com/eu-north-1_OcupftfB2',
  client_id='14nn8j8mt9n5vc8dir9jqb6n77',
  client_secret='eo1tl6ol1ogh196ud0o19c3ejaohd89b495o5mkmu0ltg300ovo',
  server_metadata_url='https://cognito-idp.eu-north-1.amazonaws.com/eu-north-1_OcupftfB2/.well-known/openid-configuration',
  client_kwargs={'scope': 'email openid profile'}
)

@bp.route('/login')
def login():
    return oauth.oidc.authorize_redirect('https://ledger.zekibalci.com/authorize')

@bp.route('/authorize')
def authorize():
    token = oauth.oidc.authorize_access_token()
    session['access_token'] = token['access_token']
    user = token['userinfo']
    # session['user'] = user
    print(user)
    session['user'] = {
        "given_name": user.get('given_name'),
        "email": user.get('email')
    }
    return redirect(url_for('main.index'))

@bp.route('/logout')
def logout():
    session.pop('user', None)
    return redirect('https://eu-north-1ocupftfb2.auth.eu-north-1.amazoncognito.com/logout?client_id=14nn8j8mt9n5vc8dir9jqb6n77&logout_uri=https://ledger.zekibalci.com/logout')
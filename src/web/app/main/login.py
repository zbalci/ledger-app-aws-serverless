from flask import session, redirect, url_for
from app.main import bp
from app.extensions import oauth

oauth.register(
  name='oidc',
  authority='https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_oXJXYU0XD',
  client_id='41aon1nfga6749103khe9ieist',
  client_secret='popkbj96gog3kngie0hfpudmr9ofrkhcgark1o9m18109om2r3c',
  server_metadata_url='https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_oXJXYU0XD/.well-known/openid-configuration',
  client_kwargs={'scope': 'phone openid email'}
)

@bp.route('/login')
def login():
    return oauth.oidc.authorize_redirect('https://edu-test.zekibalci.com/authorize')

@bp.route('/authorize')
def authorize():
    token = oauth.oidc.authorize_access_token()
    session['access_token'] = token['access_token']
    user = token['userinfo']
    session['user'] = user
    return redirect(url_for('main.index'))

@bp.route('/logout')
def logout():
    session.pop('user', None)
    return redirect('https://eu-central-1oxjxyu0xd.auth.eu-central-1.amazoncognito.com/logout?client_id=1g4m9lr7qs8galvtlvbfbtbim9&logout_uri=https://edu-test.zekibalci.com/logout')
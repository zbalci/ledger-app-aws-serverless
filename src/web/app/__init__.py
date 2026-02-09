from flask import Flask
from config import Config
from app.extensions import oauth, sess

def create_app(config_class=Config):
    app = Flask(__name__)

    app.config.from_object(config_class)
    # Initialize Flask extensions here

    #cognito
    oauth.init_app(app)
    
    #Init session
    sess.init_app(app)

    # Register blueprints here
    from app.main import bp as main_bp
    app.register_blueprint(main_bp)

    return app
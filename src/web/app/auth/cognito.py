from config import Settings, get_ssm_parameters

def build_cognito_config():

    settings = Settings()

    params = get_ssm_parameters(settings.ssm_prefix, settings.region)

    user_pool_id = params["user_pool_id"]
    client_id = params["client_id"]
    client_secret = params["client_secret"]

    authority = f"https://cognito-idp.{settings.region}.amazonaws.com/{user_pool_id}"

    server_metadata_url = f"{authority}/.well-known/openid-configuration"

    cognito_domain = (
        f"https://{settings.cognito_domain_prefix}"
        f".auth.{settings.region}.amazoncognito.com"
    )

    return {
        "authority": authority,
        "server_metadata_url": server_metadata_url,
        "client_id": client_id,
        "client_secret": client_secret,
        "cognito_domain": cognito_domain,
        "base_domain": settings.base_domain,
    }

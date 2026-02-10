from app import create_app  # `create_app` fonksiyonunu içe aktar
from config import Config  # Eğer Config gerekiyorsa ekle

# Flask uygulamasını oluştur
app = create_app(Config)

# if __name__ == '__main__':
#    context = ('cert/fullchain.pem', 'cert/privkey.pem')
#    app.run(debug=True, host='0.0.0.0', port=8443, ssl_context=context)

# Flask'ı Lambda ile çalışacak şekilde yapılandırın
# AWS Lambda ortamında WSGI'yi çalıştıran serverless_wsgi modülünü kullanın
def lambda_handler(event, context):
   from serverless_wsgi import handle_request
   return handle_request(app, event, context)
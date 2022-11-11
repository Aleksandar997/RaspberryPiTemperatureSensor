from src import service
from src import logger
from flask import Flask, jsonify
from werkzeug.middleware.dispatcher import DispatcherMiddleware
app = Flask(__name__)

@app.after_request
def after_request(response):
    header = response.headers
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Allow-Methods'] = '*'
    header['Access-Control-Allow-Headers'] = '*'
    return response

@app.errorhandler(Exception)
def handle_error(error):
    logger.log_exception(error)
    response = {
        "message": str(error),
        "status": error.code
    }
    return jsonify(response)

@app.route('/single_data', methods=['get'])
def single_data():
   return service.get_data_single()

@app.route('/temperature_data/<period_from>/<group_by_period>', methods=['get'])
def get_temperature_data(period_from, group_by_period):
    return jsonify(service.get_temperature_data(period_from, group_by_period))

@app.route('/humidity_data/<period_from>/<group_by_period>', methods=['get'])
def get_humidity_data(period_from, group_by_period):
    return jsonify(service.get_humidity_data(period_from, group_by_period))

def init():
   app.wsgi_app = DispatcherMiddleware(app.wsgi_app, service.wsgi_app_routes())
   app.run(host='0.0.0.0', port=5001, debug=False)


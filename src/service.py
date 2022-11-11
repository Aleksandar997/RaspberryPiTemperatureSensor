import adafruit_dht
import board
from datetime import datetime as dt, timezone
from src import logger
from prometheus_client import Gauge, make_wsgi_app
import requests
from src import util
import statistics
import time

dht_device = adafruit_dht.DHT22(board.D4, use_pulseio=False)

prometheus_query_url = 'http://localhost:9090/api/v1/query?query={0}[{1}]'

def to_res(temperature, humidity):
    return {
        "data": {"temperature": temperature, "humidity": humidity, "date": dt.now(timezone.utc).__str__()},
        "message": None,
        "status": 200
    }

def to_error_res(message):
    return {
        "data": None,
        "message": message,
        "status": 404
    }

def run():
    temperature_metric = Gauge('temperature', 'Temperature')
    humidity_metric = Gauge('humidity', 'Humidity')
    while True:
        try:
            temperature_metric.set_function(lambda: dht_device.temperature)
            humidity_metric.set_function(lambda: dht_device.humidity)
        except RuntimeError as error:
            continue
        except Exception as error:
            logger.log_exception(error)

def get_data_single():
    while True:
        try:
            temperature = dht_device.temperature
            humidity = dht_device.humidity
            if humidity is not None and temperature is not None:
                return to_res(temperature, humidity)
            else:
                continue

        except RuntimeError as error:
            logger.log_exception(error)
            continue
        except Exception as error:
            logger.log_exception(error)
            continue

def get_temperature_data(period_from, group_by_period):
    if period_from == None:
        period_from = '1w'
    temperature_url = prometheus_query_url.format('temperature', period_from)
    data = requests.get(temperature_url)
    return parse_history_data(data, group_by_period)

def get_humidity_data(period_from, group_by_period):
    if period_from == None:
        period_from = '1w'
    humidity_url = prometheus_query_url.format('humidity', period_from)
    data = requests.get(humidity_url)
    return parse_history_data(data, group_by_period)
    
def parse_history_data(data, group_by_period):
    if group_by_period == None:
        group_by_period = 'minute'
    result = list(util.load_json(data.text)['data']['result'])
    if len(result) == 0:
        return []
    values = result[0]['values']
    return group_data(values, group_by_period)

def group_data(data, group_by_period):
    res = []
    for d in data:
        d = parse_value(d, group_by_period)
        elem_res = [x for x in res if x['date'] == d['date']]
        if len(elem_res) > 0:
            elem_res[0]['values'].append(float(d['value']))
        else:
            res.append({'date': d['date'], 'values': [float(d['value'])], 'timestamp': d['timestamp']})
    return list(map(lambda d: {'timestamp': d['timestamp'], 'value': statistics.median(d['values'])}, res))

def parse_value(val, group_by_period):
    minute_pattern = '%d/%m/%Y %H:%M'
    hour_pattern = '%d/%m/%Y %H'
    day_pattern = '%d/%m/%Y'
    month_pattern = '%m.%Y'
    year_pattern = '%Y'
    match group_by_period:
        # case 'second':
        #     return {
        #         'date': str(dt.fromtimestamp(val[0])),
        #         'value': val[1],
        #         'timestamp': val[0]
        #     }
        
        case 'minute':
            date = dt.fromtimestamp(val[0]).strftime(minute_pattern)
            return {
                'date': date,
                'value': val[1],
                'timestamp': time.mktime(dt.strptime(date, minute_pattern).timetuple()) * 1000
            }
        case 'hour':
            date = dt.fromtimestamp(val[0]).strftime(hour_pattern)
            return {
                'date': date,
                'value': val[1],
                'timestamp': time.mktime(dt.strptime(date, hour_pattern).timetuple()) * 1000
            }
        case 'day':
            date = dt.fromtimestamp(val[0]).strftime(day_pattern)
            return {
                'date': date,
                'value': val[1],
                'timestamp': time.mktime(dt.strptime(date, day_pattern).timetuple()) * 1000
            }
        case 'month':
            date = dt.fromtimestamp(val[0]).strftime(month_pattern)
            return {
                'date': date,
                'value': val[1],
                'timestamp': time.mktime(dt.strptime(date, month_pattern).timetuple()) * 1000
            }
        case 'year':
            date = dt.fromtimestamp(val[0]).strftime(year_pattern)
            return {
                'date': date,
                'value': val[1],
                'timestamp': time.mktime(dt.strptime(date, year_pattern).timetuple()) * 1000
            }

def wsgi_app_routes():
    return  {
        '/metrics': make_wsgi_app()
    }


 

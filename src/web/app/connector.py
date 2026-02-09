import boto3
import os
from boto3.dynamodb.conditions import Key

# DynamoDB bağlantısı
def connect():
    dynamodb = boto3.resource('dynamodb', region_name='eu-north-1')  # Bölgeyi güncelleyin
    table = dynamodb.Table('transactions')  # DynamoDB tablonuzu burada belirtin
    return table

# Tüm verileri getirme
def get():
    table = connect()
    result_list = []
    response = table.scan()  # Tablodaki tüm verileri alır
    items = response['Items']
    
    for item in items:
        result_list.append({"id": item['id'], "date": item['date'], "amount": item['amount']})
    
    return result_list

# Veri ekleme
def add(id ,date, amount):
    table = connect()
    print(table)
    table.put_item(
        Item={
            'id': int(id),
            'date': date,
            'amount': amount
        }
    )

# Veri düzenleme
def edit(id, date, amount):
    table = connect()
    table.update_item(
        Key={'id': id},
        UpdateExpression="set #date = :date, amount = :amount",
        ExpressionAttributeNames={'#date': 'date'},
        ExpressionAttributeValues={':date': date, ':amount': amount}
    )

# Veri silme
def delete(id):
    table = connect()
    table.delete_item(
        Key={'id': id}
    )

# Miktara göre veri arama
def search(amount1, amount2):
    table = connect()
    result_list = []
    
    # Between şartını kullanarak arama yapıyoruz
    response = table.scan(
        FilterExpression=Key('amount').between(amount1, amount2)
    )
    
    items = response['Items']
    
    for item in items:
        result_list.append({"id": item['id'], "date": item['date'], "amount": item['amount']})
    
    return result_list
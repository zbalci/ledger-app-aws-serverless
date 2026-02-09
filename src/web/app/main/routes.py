# Import libraries
from flask import render_template, session, redirect, url_for, request, send_from_directory
from app.main import bp
# from app.mysq_connector import get, add, edit, delete, search
from app.dynamodb_connector import get, add, edit, delete, search
import time

@bp.route("/")
def index():
    user = session.get('user')

    if user:
        # Read operation: List all transactions
        transactions = get()
        return render_template("transactions.html", transactions=transactions)
    else:
        return redirect(url_for('main.login'))

def generate_id():
    return int(time.time() * 1000)

# Create operation: Display add transaction form
@bp.route("/add", methods=["GET", "POST"])
def add_transaction():
    if request.method == 'POST':
        id = generate_id()
        add(id, request.form['date'],request.form['amount'])
        return redirect(url_for("main.index"))
    return render_template("form.html")

# Update operation: Display edit transaction form
@bp.route("/edit/<int:transaction_id>", methods=["GET", "POST"])
def edit_transaction(transaction_id):
    transactions = get()
    if request.method == 'POST':
        date = request.form['date']
        amount = int(request.form['amount'])
        edit(transaction_id, date, amount)

        return redirect(url_for("main.index"))

    for transaction in transactions:
        if transaction['id'] == transaction_id:
            return render_template("edit.html", transaction=transaction)

# Delete operation: Delete a transaction
@bp.route("/delete/<int:transaction_id>")
def delete_transaction(transaction_id):
    delete(transaction_id)
    return redirect(url_for("main.index"))

# Search operation
@bp.route("/search", methods=["GET", "POST"])
def search_transaction():
    if request.method == 'GET':
        return render_template("search.html")

    if request.method == 'POST':
        min_amount = float(request.form['min_amount'])
        max_amount = float(request.form['max_amount'])
        filtered_transactions = search(min_amount,max_amount)
        return render_template("transactions.html", transactions=filtered_transactions)

# Total balance
@bp.route("/balance")
def total_balance():
    balance = 0
    transactions = get()
    for transaction in transactions:
        balance += transaction['amount']
    return render_template("balance.html", transactions=transactions, balance=balance)

# Import libraries
from flask import render_template, session, redirect, url_for, request, send_from_directory
from app.main import bp
from app.connector import get, add, edit, delete, search

# Read operation: List all transactions
@bp.route("/")
def index():
    # user = session.get('user')
    user = True
    if user:
        transactions = get()
        return render_template("transactions.html", transactions=transactions)
    else:
        return redirect(url_for('main.login'))

def get_transactions():
   transactions = get()
   return render_template("transactions.html", transactions=transactions)

# Create operation: Display add transaction form
@bp.route("/add", methods=["GET", "POST"])
def add_transaction():
    if request.method == 'POST':
        add(request.form['date'],request.form['amount'])
        return redirect(url_for("main.index"))
    return render_template("form.html")

# Update operation: Display edit transaction form
@bp.route("/edit/<int:transaction_id>", methods=["GET", "POST"])
def edit_transaction(transaction_id):
    transactions = get()
    if request.method == 'POST':
        date = request.form['date']
        amount = float(request.form['amount'])
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

from flask import Flask, render_template, request, redirect, url_for, jsonify
import psycopg2
import os
from datetime import datetime

app = Flask(__name__)

def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_NAME', 'tasktracker'),
        user=os.getenv('DB_USERNAME', 'postgres'),
        password=os.getenv('DB_PASSWORD', 'password'),
        port=os.getenv('DB_PORT', '5432')
    )

@app.route('/health')
def health():
    return 'OK', 200

@app.route('/')
def index():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, task_name, task_definition, task_due_date, completed FROM tasks ORDER BY task_due_date")
        tasks = cur.fetchall()
        cur.close()
        conn.close()
        return render_template('index.html', tasks=tasks)
    except Exception as e:
        print(f"Error loading tasks: {e}", flush=True)
        return render_template('index.html', tasks=[], error=str(e))

@app.route('/add', methods=['POST'])
def add_task():
    try:
        task_name = request.form['task_name']
        task_description = request.form['task_description']
        due_date = request.form['due_date'] if request.form['due_date'] else None
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Get the next available ID (starting from 11)
        cur.execute("SELECT COALESCE(MAX(id), 10) + 1 FROM tasks")
        next_id = cur.fetchone()[0]
        
        # Insert with explicit ID
        cur.execute("INSERT INTO tasks (id, task_name, task_definition, task_due_date) VALUES (%s, %s, %s, %s)",
                   (next_id, task_name, task_description, due_date))
        conn.commit()
        cur.close()
        conn.close()
        print(f"Added task: {task_name} with ID: {next_id}", flush=True)
    except Exception as e:
        print(f"Error adding task: {e}", flush=True)
    return redirect(url_for('index'))

@app.route('/update', methods=['POST'])
def update_task():
    try:
        task_id = request.form['task_id']
        task_name = request.form['task_name']
        task_description = request.form['task_description']
        due_date = request.form['due_date'] if request.form['due_date'] else None
        completed = request.form.get('completed', 'false') == 'true'
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE tasks SET task_name=%s, task_definition=%s, task_due_date=%s, completed=%s WHERE id=%s",
                   (task_name, task_description, due_date, completed, task_id))
        conn.commit()
        cur.close()
        conn.close()
        print(f"Updated task {task_id}: {task_name}, completed: {completed}", flush=True)
    except Exception as e:
        print(f"Error updating task: {e}", flush=True)
    return redirect(url_for('index'))

@app.route('/complete', methods=['POST'])
def complete_task():
    try:
        task_id = request.form['task_id']
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE tasks SET completed = NOT completed WHERE id=%s", (task_id,))
        conn.commit()
        cur.close()
        conn.close()
        print(f"Toggled completion for task {task_id}", flush=True)
    except Exception as e:
        print(f"Error toggling task completion: {e}", flush=True)
    return redirect(url_for('index'))

@app.route('/delete/<int:task_id>')
def delete_task(task_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM tasks WHERE id=%s", (task_id,))
        conn.commit()
        cur.close()
        conn.close()
        print(f"Deleted task {task_id}", flush=True)
    except Exception as e:
        print(f"Error deleting task: {e}", flush=True)
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=8080)

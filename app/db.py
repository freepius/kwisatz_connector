"""
Database connection management.
"""
import pyodbc
from app.config import settings

def get_connection():
    """
    Retourne une connexion pyodbc prête à l'emploi.
    À appeler dans les dépendances FastAPI (yield) pour bien fermer.
    """
    if settings.odbc_dsn.startswith("Driver="):
        conn_str = settings.odbc_dsn
    else:
        # DSN nommé
        conn_str = f"DSN={settings.odbc_dsn};"
        if settings.db_user:
            conn_str += f"UID={settings.db_user};PWD={settings.db_password or ''};"

    conn = pyodbc.connect(conn_str)
    return conn
"""
Producer router - example endpoint.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import Generator, List
from app.db import get_connection
from app.models import Producer

router = APIRouter(prefix="/producers", tags=["producers"])

def get_db_conn() -> Generator:
    conn = get_connection()
    try:
        yield conn
    finally:
        conn.close()

@router.get("/", response_model=List[Producer])
def list_producers(conn = Depends(get_db_conn)):
    """
    Exemple : récupère tous les producteurs depuis DBISAM.
    Adapte la requête SQL à tes vraies tables.
    """
    cursor = conn.cursor()
    # À ADAPTER : nom de table Kwisatz
    cursor.execute(
        "SELECT" \
        "   CODE, NOM, CONTACT," \
        "   ADRESSE_LIGNE1, ADRESSE_LIGNE2, ADRESSE_CODE_POSTAL, ADRESSE_VILLE," \
        "   EMAIL, TELEPHONE1," \
        "   DATE_CREATION, DATE_MAJ" \
        " FROM FOURNISSEUR"
    )
    rows = cursor.fetchall()

    producers: list[Producer] = []
    for r in rows:
        producers.append(
            Producer(
                code=r.CODE,
                name=r.NOM,
                email=getattr(r, "EMAIL", None),
                phone=getattr(r, "TELEPHONE1", None),
                address=" ".join(filter(None, [
                    getattr(r, "ADRESSE_LIGNE1", None),
                    getattr(r, "ADRESSE_LIGNE2", None),
                    getattr(r, "ADRESSE_CODE_POSTAL", None),
                    getattr(r, "ADRESSE_VILLE", None),
                ])),
                is_active=True,
                created_at=getattr(r, "DATE_CREATION", None),
                updated_at=getattr(r, "DATE_MAJ", None),
            )
        )

    return producers

@router.get("/{producer_id}", response_model=Producer)
def get_producer(producer_id: int, conn = Depends(get_db_conn)):
    cursor = conn.cursor()
    cursor.execute(
        "SELECT ID, NAME, EMAIL FROM PRODUCERS WHERE ID = ?",
        producer_id
    )
    row = cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Producer not found")

    return Producer(id=row.ID, name=row.NAME, email=getattr(row, "EMAIL", None))

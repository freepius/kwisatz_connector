"""
Main FastAPI application entry point
"""
from fastapi import FastAPI
from app.config import settings
from app.routers import producers

app = FastAPI(
    title="Kwisatz Connector",
    description="API connector for Kwisatz",
    version="0.1.0"
)

# Include routers
app.include_router(producers.router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "Kwisatz Connector API", "version": "0.1.0"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}

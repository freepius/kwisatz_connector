"""
Application configuration management.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database
    odbc_dsn: str = ""
    db_user: str | None = None
    db_password: str | None = None

    # API
    api_title: str = "Kwisatz Connector API"
    api_version: str = "0.1.0"
    api_prefix: str = "/api/v1"

    # Security
    secret_key: str = "change-this-secret-key-in-production"

    class Config:
        env_file = ".env"
        env_prefix = ""
        case_sensitive = False



@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()

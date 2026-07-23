import os
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

# Load .env file explicitly from agent_service or root workspace
load_dotenv(dotenv_path="agent_service/.env", override=True)
load_dotenv(dotenv_path=".env", override=True)

class Settings(BaseSettings):
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "demo_gemini_key")
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://demo.supabase.co")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "demo_service_key")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    CHECKPOINTER_DB_PATH: str = os.getenv("CHECKPOINTER_DB_PATH", "salon_checkpoints.db")

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

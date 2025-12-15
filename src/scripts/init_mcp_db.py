"""
Initialize MCP Database Tables
"""
import asyncio
import os
import asyncpg
from dotenv import load_dotenv

# Load env vars from .env file if present
dotenv_path = os.path.join(os.getcwd(), ".env")
load_dotenv(dotenv_path)

async def init_db():
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("❌ DATABASE_URL not set")
        return

    print(f"Connecting to {database_url}...")
    
    try:
        conn = await asyncpg.connect(database_url)
        
        # 1. The App Store (Available Tools)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS tools (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name VARCHAR(50) NOT NULL UNIQUE,
                description TEXT,
                mcp_endpoint VARCHAR(255) NOT NULL, 
                auth_type VARCHAR(20) DEFAULT 'none',
                is_active BOOLEAN DEFAULT TRUE
            );
        """)
        print("✅ Table 'tools' created/verified.")

        # 2. The Keychain (User Installations)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS user_tools (
                user_id UUID NOT NULL,
                tool_id UUID REFERENCES tools(id),
                is_enabled BOOLEAN DEFAULT TRUE,
                config JSONB,
                created_at TIMESTAMP DEFAULT NOW(),
                PRIMARY KEY (user_id, tool_id)
            );
        """)
        print("✅ Table 'user_tools' created/verified.")

        await conn.close()
        print("🏁 Initialization complete.")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(init_db())

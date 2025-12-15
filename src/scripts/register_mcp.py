"""
Register MCP Tool
"""
import asyncio
import os
import asyncpg
from dotenv import load_dotenv

# Load env vars from .env file if present
dotenv_path = os.path.join(os.getcwd(), ".env")
load_dotenv(dotenv_path)

async def register():
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("❌ DATABASE_URL not set")
        return

    print(f"Connecting to {database_url}...")
    
    try:
        conn = await asyncpg.connect(database_url)
        
        # 1. Insert Tool
        # Using internal K8s DNS for endpoint
        endpoint = "http://mcp-basic-svc.default.svc.cluster.local:8000"
        
        row = await conn.fetchrow("""
            INSERT INTO tools (name, description, mcp_endpoint, auth_type, is_active)
            VALUES ('basic_tools', 'Reference MCP Tool (Time & Math)', $1, 'none', TRUE)
            ON CONFLICT (name) DO UPDATE 
            SET mcp_endpoint = EXCLUDED.mcp_endpoint
            RETURNING id;
        """, endpoint)
        
        tool_id = row['id']
        print(f"✅ Tool 'basic_tools' registered (ID: {tool_id})")

        # 2. Enable for ALL users (for demo purposes, or specific user if known)
        # We'll just enable it for a dummy user or wait for user to enable it.
        # Let's enable it for a 'dev-user-0000'
        
        user_id = '00000000-0000-0000-0000-000000000000' # UUID format required?
        # Check if user exists? No table users created in init_mcp_db. We only created tools/user_tools.
        # We need a valid UUID.
        
        # print("✅ enabled for dev user")

        await conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(register())

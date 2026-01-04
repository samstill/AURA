"""
Register Figma MCP Tool
=======================

Registers the Figma MCP Server (running in Figma Desktop) 
to the Aura database.
"""
import asyncio
import os
import asyncpg
from dotenv import load_dotenv
import json

# Load env vars
dotenv_path = os.path.join(os.getcwd(), ".env")
load_dotenv(dotenv_path)

async def register_figma():
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("❌ DATABASE_URL not set")
        return

    print(f"Connecting to {database_url}...")
    
    try:
        conn = await asyncpg.connect(database_url)
        
        # Tool Definition
        tool_name = "figma"
        description = "Figma Design Integration. Read design data, layers, and components from Figma files."
        endpoint = "http://127.0.0.1:3845"
        config = {"transport": "sse"}
        
        # 1. Insert into tools table
        print(f"Registering tool: {tool_name}...")
        
        # Upsert tool definition
        await conn.execute("""
            INSERT INTO tools (name, description, mcp_endpoint, auth_type)
            VALUES ($1, $2, $3, 'none')
            ON CONFLICT (name) 
            DO UPDATE SET 
                description = EXCLUDED.description,
                mcp_endpoint = EXCLUDED.mcp_endpoint;
        """, tool_name, description, endpoint)
        
        # Get tool ID
        tool_id = await conn.fetchval("SELECT id FROM tools WHERE name = $1", tool_name)
        print(f"✅ Tool '{tool_name}' registered with ID: {tool_id}")

        # 2. Enable for all users (or specific user if needed)
        # For dev, we'll enable for all users who have tools
        # But specifically we want to ensure it's in user_tools for the current user contexts
        # Since we don't have a specific user ID easily available here without query,
        # we can just print instructions or try to add for a known user.
        # But wait, we should just let the user enable it via UI or adding it here for *all* known users.
        
        print("Enabling for all existing users...")
        users = await conn.fetch("SELECT DISTINCT user_id FROM user_tools")
        
        for user in users:
            uid = user['user_id']
            await conn.execute("""
                INSERT INTO user_tools (user_id, tool_id, is_enabled, config)
                VALUES ($1, $2, true, $3)
                ON CONFLICT (user_id, tool_id)
                DO UPDATE SET config = EXCLUDED.config, is_enabled = true;
            """, uid, tool_id, json.dumps(config))
            print(f"   - Enabled for user {uid}")

        await conn.close()
        print("🏁 Registration complete.")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(register_figma())

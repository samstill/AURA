"""
LLM Service - Gemini SDK Adapter
================================

Abstracts the Google Generative AI SDK for Project Aura.
Provides two model interfaces:
- Fast Model (Gemini Flash): Sub-second latency for quick responses
- Smart Model (Gemini Pro): Complex reasoning and tool use
"""

import os
import logging
from typing import AsyncGenerator, List, Any, Optional

import google.generativeai as genai
from google.generativeai.types import GenerateContentResponse
from openai import AsyncOpenAI, APIError

from config import settings

logger = logging.getLogger(__name__)


class LLMService:
    """
    Gemini SDK adapter providing fast and smart model access.
    """
    
    def __init__(self):
        self._initialized = False
        self.fast_model = None
        self.smart_model = None
        
        # Multi-provider clients
        self.groq_client: Optional[AsyncOpenAI] = None
        self.openrouter_client: Optional[AsyncOpenAI] = None
        self.openai_client: Optional[AsyncOpenAI] = None
        self.deepseek_client: Optional[AsyncOpenAI] = None
    
    def initialize(self):
        """
        Initialize the Gemini SDK with API key and models.
        Called during service startup.
        """
        api_key = settings.google_api_key
        if not api_key:
            logger.warning("⚠️ GOOGLE_API_KEY not found - LLM Service disabled")
            return
        
        try:
            genai.configure(api_key=api_key)
            
            # Fast Model = Gemini Flash (Reflex Lobe)
            self.fast_model = genai.GenerativeModel(settings.gemini_fast_model)
            
            # Smart Model = Gemini Pro (Deep Lobe)
            self.smart_model = genai.GenerativeModel(settings.gemini_smart_model)
            
            # OpenAI Native Client (Best tool calling)
            if settings.openai_api_key:
                try:
                    self.openai_client = AsyncOpenAI(
                        api_key=settings.openai_api_key
                    )
                    logger.info(f"✅ OpenAI Client initialized ({settings.openai_fast_model} / {settings.openai_smart_model})")
                except Exception as e:
                    logger.warning(f"⚠️ OpenAI initialization failed: {e}")
            
            # DeepSeek Native Client
            if settings.deepseek_api_key:
                try:
                    self.deepseek_client = AsyncOpenAI(
                        api_key=settings.deepseek_api_key,
                        base_url="https://api.deepseek.com"
                    )
                    logger.info(f"✅ DeepSeek Client initialized ({settings.deepseek_model})")
                except Exception as e:
                    logger.warning(f"⚠️ DeepSeek initialization failed: {e}")
            
            # Groq Initialization
            if settings.groq_api_key:
                try:
                    self.groq_client = AsyncOpenAI(
                        api_key=settings.groq_api_key,
                        base_url="https://api.groq.com/openai/v1"
                    )
                    logger.info(f"✅ Groq Client initialized ({settings.groq_fast_model})")
                except Exception as e:
                    logger.warning(f"⚠️ Groq initialization failed: {e}")

            # OpenRouter Initialization
            if settings.openrouter_api_key:
                try:
                    self.openrouter_client = AsyncOpenAI(
                        api_key=settings.openrouter_api_key,
                        base_url="https://openrouter.ai/api/v1"
                    )
                    logger.info(f"✅ OpenRouter Client initialized")
                except Exception as e:
                    logger.warning(f"⚠️ OpenRouter initialization failed: {e}")
            
            self._initialized = True
            logger.info(f"✅ LLM Service ready")
            
        except Exception as e:
            logger.error(f"❌ LLM Service initialization failed: {e}")
            raise
    
    @property
    def is_initialized(self) -> bool:
        return self._initialized
    
    async def get_reflex_response(
        self, 
        user_query: str, 
        system_prompt: str = "",
        include_model_header: bool = True
    ) -> AsyncGenerator[str, None]:
        """
        FAST PATH (Enhanced): Multi-provider cascade.
        Priority: Groq (Llama3) -> Gemini Flash -> OpenRouter
        """
        if not self._initialized:
            yield "[System Error: LLM Service not initialized]"
            return

        # 1. Try Groq (Fastest)
        if self.groq_client:
            try:
                # logger.debug("⚡ Trying Groq for reflex response...")
                async for chunk in self._stream_openai_compatible(
                    self.groq_client, 
                    settings.groq_fast_model, 
                    user_query, 
                    system_prompt,
                    include_model_header=include_model_header
                ):
                    yield chunk
                return  # Success, exit
            except Exception as e:
                logger.warning(f"⚠️ Groq failed, falling back: {e}")

        # 2. Try Gemini Flash (Reliable Backup)
        try:
            # logger.debug("⚡ Trying Gemini Flash for reflex response...")
            full_prompt = user_query
            if system_prompt:
                full_prompt = f"System: {system_prompt}\nUser: {user_query}"
            
            if include_model_header:
                yield f"||MODEL:{settings.gemini_fast_model}||"

            response = await self.fast_model.generate_content_async(
                full_prompt,
                stream=True
            )
            async for chunk in response:
                if chunk.text:
                    yield chunk.text
            return  # Success, exit
        except Exception as e:
            logger.warning(f"⚠️ Gemini Flash failed, falling back: {e}")

        # 3. Try OpenRouter (Final Fallback)
        if self.openrouter_client:
            try:
                # logger.debug("⚡ Trying OpenRouter for reflex response...")
                async for chunk in self._stream_openai_compatible(
                    self.openrouter_client, 
                    settings.openrouter_fast_model, 
                    user_query, 
                    system_prompt,
                    include_model_header=include_model_header
                ):
                    yield chunk
                return
            except Exception as e:
                logger.error(f"❌ OpenRouter failed: {e}")

        yield "[System Error: All LLM providers failed. Check quotas/keys.]"

    async def _stream_openai_compatible(
        self, 
        client: AsyncOpenAI, 
        model: str, 
        prompt: str, 
        system: str,
        include_model_header: bool = True
    ) -> AsyncGenerator[str, None]:
        """Helper for streaming from OpenAI-compatible APIs (Groq/OpenRouter)"""
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        try:
           if include_model_header:
               yield f"||MODEL:{model}||"

           stream = await client.chat.completions.create(
               model=model,
               messages=messages,
               stream=True,
               max_tokens=512
           )
           
           async for chunk in stream:
               content = chunk.choices[0].delta.content
               if content:
                   yield content
        except Exception as e:
           raise e
    
    async def get_agent_response(
        self, 
        prompt: str, 
        system_instruction: str = "",
        tools: Optional[List[Any]] = None
    ) -> GenerateContentResponse:
        """
        SLOW PATH: Uses Gemini Pro.
        Optimized for complex reasoning and tool use.
        
        Args:
            prompt: User's query
            system_instruction: System context/persona
            tools: List of tool functions for function calling
            
        Returns:
            Full response object from Gemini Pro
        """
        if not self._initialized:
            raise RuntimeError("LLM Service not initialized")
            
        try:
            # Configure model with tools if present
            model = self.smart_model
            if tools:
                model = genai.GenerativeModel(
                    settings.gemini_smart_model,
                    tools=tools
                )
            
            # Start chat session with system context
            chat = model.start_chat(history=[
                {"role": "user", "parts": [f"System Instruction: {system_instruction}"]}
            ])
            
            response = await chat.send_message_async(prompt)
            return response
            
        except Exception as e:
            logger.error(f"Gemini Pro error: {e}")
            raise


# Singleton instance
llm_service = LLMService()

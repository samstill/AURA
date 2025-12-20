/**
 * Type definitions for Encresa Systems SDK
 */

export interface ConnectionResult {
    connected: boolean;
    version: string;
    status: string;
}

export interface AuthResult {
    authenticated: boolean;
    message: string;
}

/**
 * Initializes the Encresa Systems connection.
 */
export function connect(): ConnectionResult;

/**
 * Returns the current SDK version.
 */
export function version(): string;

/**
 * Placeholder for AURA protocol authentication.
 */
export function authenticate(apiKey: string): AuthResult;

/**
 * Current SDK version.
 */
export const VERSION: string;

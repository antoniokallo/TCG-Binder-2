//
//  SupabaseManager.swift
//  TCGBinder2.0
//
//  Created by Edward Kogos on 8/16/25.
//

// SupabaseManager.swift

import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://soydppiaoumxuqdpeytl.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNveWRwcGlhb3VteHVxZHBleXRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyMjUxODYsImV4cCI6MjA3MDgwMTE4Nn0.xMQuORZKtUL8r3hjRQcsUAHxmV6877qKf1idyXpMkUs"
)

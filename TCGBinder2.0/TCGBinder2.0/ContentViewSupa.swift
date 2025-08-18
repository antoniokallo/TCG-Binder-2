//
//  ContentViewSupa.swift
//  TCGBinder2.0
//
//  Created by Edward Kogos on 8/15/25.
//
import Supabase
import SwiftUI

struct ContentViewSupa: View {
  @State var todos: [Todo] = []

  var body: some View {
    NavigationStack {
      List(todos) { todo in
        Text(todo.title)
      }
      .navigationTitle("Todos")
      .task {
        do {
          todos = try await supabase.from("todos").select().execute().value
        } catch {
          debugPrint(error)
        }
      }
    }
  }
}

#Preview {
  ContentView()
}

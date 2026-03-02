struct ModelPickerView: View {
  @Bindable var brain: JosieBrain
  @Environment(\.dismiss) var dismiss
  let flavors = ["JosieStheno", "JosieSelf", "JosieVanessa", "JosieXwin"]

  var body: some View {
    NavigationStack {
      List(flavors, id: \.self) { flavor in
        let exists = brain.availableModels.contains(flavor)
        HStack {
          Circle().fill(exists ? .green : .gray).frame(width: 8, height: 8)
          Text(flavor).foregroundColor(exists ? .primary : .secondary)
          Spacer()
          if exists {
            Button("Load") {
              Task {
                await brain.loadModel(flavor)
                dismiss()
              }
            }
            .buttonStyle(.borderedProminent).tint(.pink)
          }
        }.opacity(exists ? 1.0 : 0.5)
      }
      .navigationTitle("Brains")
    }
  }
}

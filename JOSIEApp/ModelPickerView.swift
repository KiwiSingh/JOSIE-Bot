import SwiftUI

struct ModelPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModel: String
    let models: [String]

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    VStack(spacing: 12) {
                        Text("No local models found")
                            .font(.headline)
                        Text("Add models in Files > JOSIE > Models")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(models, id: \.self) { model in
                        Button {
                            selectedModel = model
                            dismiss()
                        } label: {
                            HStack {
                                Text(model)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Spacer()

                                if model == selectedModel {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

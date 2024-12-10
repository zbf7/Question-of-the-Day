import SwiftUI

struct AppTheme {
    static let primary = Color(hex: "5B4CEC")
    static let primaryLight = Color(hex: "7A6EF1")
    static let primaryDark = Color(hex: "4438B8")
    static let background = Color(hex: "F8F8FC")
    static let text = Color(hex: "1A1A2F")
    static let success = Color(hex: "4CAF50")
    static let error = Color(hex: "DC3545")
    static let warning = Color(hex: "FFC107")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = QuestionViewModel()
    
    var body: some View {
        NavigationView {
            QuestionView(viewModel: viewModel)
        }
        .background(AppTheme.background)
        .tint(AppTheme.primary)
    }
}

// Models
struct Category: Identifiable {
    let id = UUID()
    let name: String
    let systemIcon: String
    let questions: [Question]
}

struct Question: Identifiable, Codable {
    let id: UUID
    let text: String
    let options: [String]?
    
    init(id: UUID = UUID(), text: String, options: [String]? = nil) {
        self.id = id
        self.text = text
        self.options = options
    }
}

// ViewModel
class QuestionViewModel: ObservableObject {
    @Published var selectedCategory: Category?
    @Published var currentQuestion: Question?
    @Published var userAnswer: String = ""
    @Published var hasAnsweredToday: Bool = false
    @Published var answeredDates: Set<String> = []
    @Published var answeredCategoriesForToday: Set<UUID> = []
    
    let categories: [Category] = [
        Category(name: "Partner Questions", 
                systemIcon: "heart.fill",
                questions: [
                    Question(text: "What's one thing your partner did recently that made you smile?"),
                    Question(text: "What's a new activity you'd like to try together?"),
                    Question(text: "What's your partner's love language?", 
                            options: ["Words of Affirmation", "Acts of Service", "Physical Touch", "Quality Time", "Receiving Gifts"])
                ]),
        
        Category(name: "Friend Questions",
                systemIcon: "person.2.fill",
                questions: [
                    Question(text: "Which friend haven't you contacted in a while?"),
                    Question(text: "What's one way you can be a better friend today?"),
                    Question(text: "What activity would you like to plan with your friends?")
                ]),
        
        Category(name: "Date Questions",
                systemIcon: "sparkles",
                questions: [
                    Question(text: "What's your idea of a perfect date?"),
                    Question(text: "What are your long-term goals?"),
                    Question(text: "What's your favorite way to relax?", 
                            options: ["Reading", "Exercise", "Movies", "Nature", "Music"])
                ]),
        
        Category(name: "Self-Reflection",
                systemIcon: "person.fill.questionmark",
                questions: [
                    Question(text: "What's one thing you're proud of about yourself?"),
                    Question(text: "What's a habit you'd like to develop?"),
                    Question(text: "How are you feeling today?", 
                            options: ["Energetic", "Content", "Tired", "Anxious", "Excited"])
                ])
    ]
    
    init() {
        loadLastCategory()
        checkIfAnsweredToday()
        loadAnsweredDates()
        loadAnsweredCategories()
    }
    
    private func loadLastCategory() {
        if let savedCategoryIndex = UserDefaults.standard.object(forKey: "lastSelectedCategory") as? Int {
            selectedCategory = categories[savedCategoryIndex]
            loadTodayQuestion()
        }
    }
    
    func selectCategory(_ category: Category) {
        selectedCategory = category
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            UserDefaults.standard.set(index, forKey: "lastSelectedCategory")
        }
        loadTodayQuestion()
    }
    
    private func loadTodayQuestion() {
        guard let category = selectedCategory else { return }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let questionIndex = dayOfYear % category.questions.count
        currentQuestion = category.questions[questionIndex]
    }
    
    private func checkIfAnsweredToday() {
        let defaults = UserDefaults.standard
        let lastAnsweredDate = defaults.object(forKey: "lastAnsweredDate") as? Date
        
        if let lastDate = lastAnsweredDate,
           Calendar.current.isDateInToday(lastDate) {
            hasAnsweredToday = true
            userAnswer = defaults.string(forKey: "lastAnswer") ?? ""
        } else {
            hasAnsweredToday = false
            userAnswer = ""
        }
    }
    
    private func loadAnsweredDates() {
        if let dates = UserDefaults.standard.array(forKey: "answeredDates") as? [String] {
            answeredDates = Set(dates)
        }
    }
    
    func hasAnsweredOn(_ date: Date) -> Bool {
        let dateString = dateToString(date)
        return answeredDates.contains(dateString)
    }
    
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func loadAnsweredCategories() {
        if let lastAnsweredDate = UserDefaults.standard.object(forKey: "lastAnsweredDate") as? Date,
           Calendar.current.isDateInToday(lastAnsweredDate),
           let categoryIds = UserDefaults.standard.array(forKey: "answeredCategoriesForToday") as? [String] {
            answeredCategoriesForToday = Set(categoryIds.compactMap { UUID(uuidString: $0) })
        } else {
            // Reset if it's a new day
            answeredCategoriesForToday = []
            UserDefaults.standard.removeObject(forKey: "answeredCategoriesForToday")
        }
    }
    
    func hasAnsweredCategory(_ category: Category) -> Bool {
        answeredCategoriesForToday.contains(category.id)
    }
    
    func submitAnswer() {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "lastAnsweredDate")
        defaults.set(userAnswer, forKey: "lastAnswer")
        
        let todayString = dateToString(Date())
        answeredDates.insert(todayString)
        defaults.set(Array(answeredDates), forKey: "answeredDates")
        
        if let category = selectedCategory {
            answeredCategoriesForToday.insert(category.id)
            let categoryIds = answeredCategoriesForToday.map { $0.uuidString }
            defaults.set(categoryIds, forKey: "answeredCategoriesForToday")
        }
        
        hasAnsweredToday = true
    }
}

struct CategorySelectionView: View {
    @ObservedObject var viewModel: QuestionViewModel
    
    var body: some View {
        List(viewModel.categories) { category in
            Button(action: { viewModel.selectCategory(category) }) {
                HStack {
                    Image(systemName: category.systemIcon)
                        .foregroundColor(AppTheme.primary)
                        .font(.title2)
                    
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                    
                    Spacer()
                    
                    if viewModel.hasAnsweredCategory(category) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Question Categories")
        .background(AppTheme.background)
    }
}

struct QuestionView: View {
    @ObservedObject var viewModel: QuestionViewModel
    
    var body: some View {
        if let category = viewModel.selectedCategory {
            VStack(spacing: 20) {
                if viewModel.hasAnsweredCategory(category) {
                    answeredView
                } else {
                    activeQuestionView
                }
            }
            .padding()
            .navigationTitle(category.name)
        } else {
            CategorySelectionView(viewModel: viewModel)
        }
    }
    
    private var activeQuestionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            DateHeaderView(date: Date())
            
            CalendarDotView(date: Date(), viewModel: viewModel)
            
            Text("Today's Question:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(viewModel.currentQuestion?.text ?? "")
                .font(.title2)
                .fontWeight(.medium)
            
            if let options = viewModel.currentQuestion?.options {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        viewModel.userAnswer = option
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(AppTheme.text)
                            Spacer()
                            if viewModel.userAnswer == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                }
            } else {
                TextEditor(text: $viewModel.userAnswer)
                    .frame(height: 100)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: {
                viewModel.submitAnswer()
            }) {
                Text("Submit")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.userAnswer.isEmpty ? Color.gray : AppTheme.primary)
                    .cornerRadius(10)
            }
            .disabled(viewModel.userAnswer.isEmpty)
            
            Spacer()
        }
        .background(AppTheme.background)
    }
    
    private var answeredView: some View {
        VStack(alignment: .leading, spacing: 20) {
            DateHeaderView(date: Date())
            
            CalendarDotView(date: Date(), viewModel: viewModel)
            
            Text("You've answered today's question:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(viewModel.currentQuestion?.text ?? "")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Your answer:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(viewModel.userAnswer)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            Text("Come back tomorrow for a new question!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                viewModel.selectedCategory = nil
            }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Choose Another Category")
                }
                .foregroundColor(.blue)
            }
            .padding(.top)
            
            Spacer()
        }
    }
}

struct DateHeaderView: View {
    let date: Date
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.headline)
            .foregroundColor(AppTheme.text)
            .padding(.bottom, 8)
    }
}

struct CalendarDotView: View {
    let date: Date
    @ObservedObject var viewModel: QuestionViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calendar")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(-6...0, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                    Circle()
                        .fill(viewModel.hasAnsweredOn(date) ? AppTheme.primary : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
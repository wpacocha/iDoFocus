import SwiftUI
import CoreData
import AVFoundation
import UIKit
import CoreMotion
import ActivityKit
import struct _Concurrency.Task


struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Task.title, order: .forward)],
        animation: .default)
    private var tasks: FetchedResults<Task>
    
    var player: AVAudioPlayer?
    
    @State private var newTaskTitle: String = ""
    @State private var selectedTask: Task? = nil
    @State private var showTimerOverlay: Bool = false
    @State private var timeRemaining: Int = 1500
    @State private var timerRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var showCompletionAlert: Bool = false
    @State private var showSettingsOverlay: Bool = false
    @State private var selectedWorkDuration: Int = 25
    @State private var selectedBreakDuration: Int = 5
    @State private var customWorkDuration: String = ""
    @State private var customBreakDuration: String = ""
    @State private var isBreakTime: Bool = false
    @State private var quoteText: String = "Loading..."
    @State private var motionManager: CMMotionManager = CMMotionManager()
    @State private var isDeviceMoving = false
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerView
                addTaskView
                tasksListView
            }
            .padding()
            .background(isDarkMode ? Color(red:50/255, green:60/255,blue:75/255) : Color.white)
            .foregroundColor(isDarkMode ? .white : .black)
            .onAppear(perform: requestNotificationPermissions)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsOverlay = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .overlay(timerOverlay)
            .overlay(settingsOverlay)
            .alert("Did you finish your task?", isPresented: $showCompletionAlert) {
                Button("Yes") { markTaskCompleted() }
                Button("No") {
                    showTimerOverlay = false
                    startBreak()
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Tasks")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(isDarkMode ? .white : .black)
            Spacer()
        }
    }
    
    private var addTaskView: some View {
        HStack {
            TextField(
                "",
                text: $newTaskTitle,
                prompt: Text("Enter new task")
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
            )
            .padding(10)
            .background(isDarkMode ? Color(red:50/255, green:60/255,blue:75/255) : Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.4), lineWidth: 1)
            )
            .foregroundColor(isDarkMode ? .white : .black)
            
            Button(action: addTask) {
                Image(systemName: "plus")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
    }
    
    private var tasksListView: some View {
        List {
            ForEach(tasks) { task in
                HStack {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .onTapGesture { toggleTask(task) }
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(task.title ?? "")
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                    
                    Button("Work") {
                        startWork(on: task)
                    }
                    .padding(8)
                    .background(isDarkMode ? Color.blue.opacity(0.8) : Color.blue)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDarkMode ? Color(red: 60/255, green: 70/255, blue: 85/255) : Color(.systemGray6))
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .transition(.move(edge: .top))
                .swipeActions(edge: .trailing, allowsFullSwipe: true){
                    Button(role: .destructive){
                        if let index = tasks.firstIndex(of: task) {
                            deleteTasks(at: IndexSet(integer: index))
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listStyle(.plain)
    }
    
    private var timerOverlay: some View {
        Group {
            if showTimerOverlay {
                (isBreakTime ? Color(red: 0.8, green: 1.0, blue: 0.8) : Color(red: 1.0, green: 0.95, blue: 0.7))
                    .opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                    .overlay {
                        VStack(spacing: 20) {
                            Text(isBreakTime ? "Break Time" : "Work Time")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            
                            Text(formatTime())
                                .font(.system(size: 60, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.top, 10)
                            
                            Text("\"\(quoteText)\"")
                                .font(.body)
                                .fontWeight(.light)
                                .italic()
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            
                            HStack(spacing: 20) {
                                Button("Stop") {
                                    stopTimer()
                                    showTimerOverlay = false
                                }
                                .frame(width: 100, height: 44)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(10)
                                
                                Button("Reset") {
                                    resetTimer()
                                }
                                .frame(width: 100, height: 44)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.black)
                                .cornerRadius(10)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 80)
                    }
            }
        }
    }
    
    private var settingsOverlay: some View {
        Group {
            if showSettingsOverlay {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            Text("Settings")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()
                            
                            Toggle(isOn: $isDarkMode) {
                                Text("Dark mode")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Button("Pomodoro 25/5") {
                                selectedWorkDuration = 25
                                selectedBreakDuration = 5
                                showSettingsOverlay = false
                            }
                            .frame(width: 200, height: 44)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Button("Long 50/10") {
                                selectedWorkDuration = 50
                                selectedBreakDuration = 10
                                showSettingsOverlay = false
                            }
                            .frame(width: 200, height: 44)
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            VStack(spacing: 10) {
                                TextField("Work minutes", text: $customWorkDuration)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                                
                                TextField("Break minutes", text: $customBreakDuration)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                                
                                Button("Save Custom") {
                                    if let work = Int(customWorkDuration), let breakTime = Int(customBreakDuration) {
                                        selectedWorkDuration = work
                                        selectedBreakDuration = breakTime
                                        showSettingsOverlay = false
                                    }
                                }
                                .frame(width: 150, height: 44)
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Button("Close") {
                                showSettingsOverlay = false
                            }
                            .padding(.top, 20)
                            .foregroundColor(.white)
                        }
                            .padding()
                    )
            }
        }
    }
    
    private func addTask() {
        let newTask = Task(context: viewContext)
        newTask.title = newTaskTitle
        newTask.isCompleted = false
        saveContext()
        newTaskTitle = ""
    }
    
    private func toggleTask(_ task: Task) {
        task.isCompleted.toggle()
        saveContext()
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        offsets.map { tasks[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
    
    private func startWork(on task: Task) {
        selectedTask = task
        timeRemaining = selectedWorkDuration * 60
        isBreakTime = false
        showTimerOverlay = true
        fetchQuote()
        startTimer()
        startLiveActivity(task: task)
        startGyroscope()
    }
    
    private func startBreak(){
        timeRemaining = selectedBreakDuration * 60
        isBreakTime = true
        showTimerOverlay = true
        fetchQuote()
        startTimer()
        stopGyroscope()
    }
    
    private func startTimer() {
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                updateLiveActivityState()
            } else {
                timer?.invalidate()
                timer = nil
                timerRunning = false
                if isBreakTime {
                    breakEnded()
                } else {
                    showCompletionAlert = true
                }
            }
        }
    }
    
    private func breakEnded(){
        playNotification()
        startWork(on: selectedTask!)
    }
    
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        stopGyroscope()
        endLiveActivity()
    }
    
    private func resetTimer() {
        stopTimer()
        timeRemaining = selectedWorkDuration * 60
    }
    
    private func formatTime() -> String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func markTaskCompleted() {
        if let task = selectedTask {
            task.isCompleted = true
            saveContext()
        }
        showTimerOverlay = false
    }
    
    
    private func playNotification() {
        AudioServicesPlaySystemSound(SystemSoundID(1005))
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private func fetchQuote() {
        let urlString = "http://api.quotable.io/random"
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching quote: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            
            do {
                let quoteResponse = try JSONDecoder().decode(QuoteResponse.self, from: data)
                DispatchQueue.main.async {
                    self.quoteText = quoteResponse.content
                    print("Fetched quote: \(quoteText)")
                }
            } catch {
                print("Error decoding quote: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    struct QuoteResponse: Decodable {
        let content: String
        let author: String
    }
    
    private func startGyroscope() {
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { (data, error) in
                guard let data = data else { return }
                
                if abs(data.rotationRate.x) > 0.5 || abs(data.rotationRate.y) > 0.5 || abs(data.rotationRate.z) > 0.5 {
                    if !self.isDeviceMoving {
                        self.isDeviceMoving = true
                        self.showFocusReminder()
                    }
                } else {
                    self.isDeviceMoving = false
                }
            }
        }
    }
    
    
    
    private func showFocusReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Attention!"
        content.body = "Focus on your task!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "focusReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func stopGyroscope() {
        motionManager.stopGyroUpdates()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Permission granted")
            } else {
                print("Permission denied")
            }
        }
    }
    
    func startLiveActivity(task: Task){
        let attributes = FocusActivityAttributes(taskName: task.title ?? "Task")
        let initialState = FocusActivityAttributes.ContentState(timeRemaining: timeRemaining, isBreak: isBreakTime)
        
        do{
            let _ = try Activity<FocusActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start live Activity: \(error)")
        }
        
    }
    
    private func updateLiveActivityState() {
        for activity in Activity<FocusActivityAttributes>.activities {
            _Concurrency.Task {
                await activity.update(ActivityContent(state: FocusActivityAttributes.ContentState(
                    timeRemaining: timeRemaining,
                    isBreak: isBreakTime
                ), staleDate: nil))
                
            }
        }
    }
    
    private func endLiveActivity() {
        for activity in Activity<FocusActivityAttributes>.activities {
            _Concurrency.Task {
                await activity.end(
                    ActivityContent(state: FocusActivityAttributes.ContentState(
                        timeRemaining: 0,
                        isBreak: isBreakTime
                    ), staleDate: nil),
                    dismissalPolicy: .immediate
                )
                
            }
        }
        
        
    }
}

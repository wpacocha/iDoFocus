import SwiftUI
import CoreData
import AVFoundation
import UIKit
import CoreMotion

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


    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Enter new task", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)

                    Button(action: addTask) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)

                List {
                    ForEach(tasks) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .onTapGesture {
                                    toggleTask(task)
                                }
                            Text(task.title ?? "")

                            Spacer()

                            Button("Work") {
                                startWork(on: task)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
            .navigationTitle("Tasks")
            .onAppear{
                requestNotificationPermissions()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettingsOverlay = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .overlay(timerOverlay)
            .overlay(settingsOverlay)
            .alert("Did you finish your task?", isPresented: $showCompletionAlert) {
                Button("Yes") {
                    markTaskCompleted()
                }
                Button("No") {
                    showTimerOverlay = false
                    startBreak()
                }
            }
        }
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
                            
                            Text("“\(quoteText)”")
                                .font(.body)
                                .fontWeight(.light)
                                .italic()
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .padding(.horizontal)
                                .padding(.bottom,10)

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
    
}

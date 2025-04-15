//
//  ContentView.swift
//  BitirmeTez
//
//  Created by Altay on 15.04.2025.
//

import SwiftUI
import CocoaMQTT

class MQTTManager: ObservableObject {
    @Published var messages: [MQTTMessage] = []
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Bağlantı Yok"
    
    private var mqttClient: CocoaMQTT?
    
    func setupMQTT(host: String, port: UInt16, clientID: String) {
        mqttClient = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqttClient?.username = ""
        mqttClient?.password = ""
        mqttClient?.keepAlive = 60
        mqttClient?.delegate = self
    }
    
    func connect() {
        connectionStatus = "Connecting..."
        _ = mqttClient?.connect()
    }
    
    func disconnect() {
        mqttClient?.disconnect()
    }
    
    func subscribe(to topic: String) {
        mqttClient?.subscribe(topic)
    }
    
    func publish(to topic: String, message: String) {
        mqttClient?.publish(topic, withString: message)
    }
}

extension MQTTManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            isConnected = true
            connectionStatus = "Connected"
        } else {
            connectionStatus = "Connection failed: \(ack)"
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        // Handle published message confirmation
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        // Handle publish acknowledgment
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        if let messageString = message.string {
            let newMessage = MQTTMessage(topic: message.topic, content: messageString, timestamp: Date())
            DispatchQueue.main.async {
                self.messages.append(newMessage)
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        // Handle subscription confirmation
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        // Handle unsubscription confirmation
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        // Handle ping
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        // Handle pong
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        isConnected = false
        connectionStatus = "Disconnected"
        if let error = err {
            connectionStatus = "Disconnected with error: \(error.localizedDescription)"
        }
    }
}

struct MQTTMessage: Identifiable {
    var id = UUID()
    let topic: String
    let content: String
    let timestamp: Date
    
    // Parsed data
    var parkingSpaces: String?
    var information: String?
    
    init(topic: String, content: String, timestamp: Date) {
        self.id = UUID()
        self.topic = topic
        self.content = content
        self.timestamp = timestamp
        
        // Parse JSON if possible
        parseJSON()
    }
    
    mutating func parseJSON() {
        if let jsonData = content.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    parkingSpaces = json["otopark_bos_alan"] as? String
                    information = json["bilgilendirme"] as? String
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }
}

struct MessageCard: View {
    let message: MQTTMessage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.topic)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(formatDate(message.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            if let parkingSpaces = message.parkingSpaces {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundColor(.green)
                    Text("Boş Park Alanı: \(parkingSpaces)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
            
            if let information = message.information {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(information)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct MessagePreviewCard: View {
    let message: MQTTMessage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.topic)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let parkingSpaces = message.parkingSpaces {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Boş Park Alanı: \(parkingSpaces)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct ContentView: View {
    @StateObject private var mqttManager = MQTTManager()
    @State private var host = "broker.hivemq.com"
    @State private var port = "1883"
    @State private var clientID = "SwiftUI_\(UUID().uuidString.prefix(8))"
    @State private var topic = "Muhendislik"
    @State private var message = ""
    @State private var showConnectionSheet = false
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            dashboardView
                .tabItem {
                    Label("Anasayfa", systemImage: "chart.bar.xaxis")
                }
                .tag(0)
            
            // Messages Tab
            messagesView
                .tabItem {
                    Label("Mesajlar", systemImage: "message.fill")
                }
                .tag(1)
            
            // Settings Tab
            settingsView
                .tabItem {
                    Label("Ayarlar", systemImage: "gear")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showConnectionSheet) {
            connectionSettingsView
        }
        .onAppear {
            // Automatically connect to MQTT server when app launches
            if !mqttManager.isConnected {
                if let portNumber = UInt16(port) {
                    mqttManager.setupMQTT(host: host, port: portNumber, clientID: clientID)
                    mqttManager.connect()
                    
                    // Subscribe to the topic after connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if mqttManager.isConnected {
                            mqttManager.subscribe(to: topic)
                        }
                    }
                }
            }
        }
    }
     
    
    // DASHBOARD VIEW
    private var dashboardView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    connectionStatusCard
                     
                    // Statistics Cards
                    HStack(spacing: 15) {
                        statisticsCard(title: "Boş Park Alanı", value: mqttManager.messages.last?.parkingSpaces ?? "0", icon: "car.fill", color: .green)
                    }
                    .padding(.horizontal)
                    
                    // Latest Messages Preview
                    latestMessagesPreview
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .padding(.top, 45)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    connectionButton
                }
            }
        }
    }
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bağlantı Durumu")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(mqttManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text(host)
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text(port)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(mqttManager.connectionStatus)
                        .font(.subheadline)
                        .foregroundColor(mqttManager.isConnected ? .green : .red)
               
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    private func statisticsCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var latestMessagesPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bilgilendirmeler")
                    .font(.headline)
                Spacer()
                Button(action: {
                    selectedTab = 1
                }) {
                    Text("Tümünü Gör")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            if mqttManager.messages.isEmpty {
                emptyMessagesView
            } else {
                ForEach(Array(mqttManager.messages.suffix(3).reversed().enumerated()), id: \.element.id) { index, message in
                    MessagePreviewCard(message: message)
                }
            }
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 15) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Yeni Mesaj Yok")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Otopark sunucunuza bağlanarak güncel mesajları alın.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MESSAGES VIEW
    private var messagesView: some View {
        NavigationView {
            Group {
                if mqttManager.messages.isEmpty {
                    emptyMessagesFullView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(mqttManager.messages.reversed()) { message in
                                MessageCard(message: message)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Messages")
            .overlay(
                VStack {
                    Spacer()
                    if mqttManager.isConnected {
                        publishMessageView
                    }
                }
            )
        }
    }
    
    private var emptyMessagesFullView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Yeni Mesaj Yok")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Text("Otopark sunucunuza bağlanarak güncel mesajları alın.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !mqttManager.isConnected {
                Button(action: {
                    showConnectionSheet = true
                }) {
                    Text("Bağlantıyı Ayarla")
                        .fontWeight(.medium)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // SETTINGS VIEW
    private var settingsView: some View {
        NavigationView {
            Form {
                Section(header: Text("Bağlantı Ayarları")) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Host", text: $host)
                    }
                    
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Client ID", text: $clientID)
                    }
                }
                
                Section(header: Text("Konu")) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Topic", text: $topic)
                    }
                }
                
                Section {
                    Button(action: {
                        if mqttManager.isConnected {
                            mqttManager.disconnect()
                        }
                        
                        if let portNumber = UInt16(port) {
                            mqttManager.setupMQTT(host: host, port: portNumber, clientID: clientID)
                            mqttManager.connect()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                if mqttManager.isConnected {
                                    mqttManager.subscribe(to: topic)
                                }
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Kaydet")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Hakkında")) {
                    HStack {
                        Text("MSKU FBE BSM Y.L.")
                        Spacer()
                        Text("v1.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Yapımcı")
                        Spacer()
                        Text("Altay Kırlı")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
    
    private var publishMessageView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Type your message...", text: $message)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                
                Button(action: {
                    if !message.isEmpty {
                        mqttManager.publish(to: topic, message: message)
                        message = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(message.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(22)
                }
                .disabled(message.isEmpty)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -5)
            )
        }
    }
    
    private var connectionButton: some View {
        Button(action: {
            if mqttManager.isConnected {
                mqttManager.disconnect()
            } else {
                if let portNumber = UInt16(port) {
                    mqttManager.setupMQTT(host: host, port: portNumber, clientID: clientID)
                    mqttManager.connect()
                    
                    // Subscribe to the topic after connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if mqttManager.isConnected {
                            mqttManager.subscribe(to: topic)
                        }
                    }
                }
            }
        }) {
            HStack {
                Circle()
                    .fill(mqttManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(mqttManager.isConnected ? "Bağlantı Kes" : "Bağlan")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(mqttManager.isConnected ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
            )
            .foregroundColor(mqttManager.isConnected ? .red : .green)
        }
    }
    
    private var connectionSettingsView: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Settings")) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Host", text: $host)
                    }
                    
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Client ID", text: $clientID)
                    }
                }
                
                Section(header: Text("Topic")) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Topic", text: $topic)
                    }
                }
                
                Section {
                    Button(action: {
                        showConnectionSheet = false
                    }) {
                        Text("Save and Close")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("MQTT Settings")
            .navigationBarItems(trailing: Button("Close") {
                showConnectionSheet = false
            })
        }
    }
}

#Preview {
    ContentView()
}

//
//  SettingsView.swift
//  DarkModeBuddy
//
//  Created by Guilherme Rambo on 23/02/21.
//

import SwiftUI
import DarkModeBuddyCore

struct SettingsView: View {
    @EnvironmentObject var reader: DMBAmbientLightSensorReader
    @EnvironmentObject var settings: DMBSettings

    private let darknessInterval: ClosedRange<Double> = 0...3000

    @State private var isShowingDarknessValueOutOfBoundsAlert = false
    @State private var isEditingAmbientLightLevelManually = false
    @State private var editingAmbientLightManuallyTextFieldStore = ""
    @State private var showFromTimePicker = false
    @State private var showToTimePicker = false
    
    private func formatTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        Group {
            if reader.isSensorReady {
                settingsControls
            } else {
                UnsupportedMacView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.top, .bottom])
        .padding([.leading, .trailing], 22)
        .onAppear { reader.activate() }
    }
    
    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 32) {
            Toggle(
                "Launch at Login",
                isOn: $settings.isLaunchAtLoginEnabled
            )
            
            Toggle(
                "Change Theme Automatically",
                isOn: $settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled
            )
            
            Group {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Dark When Ambient Light Falls Below:")
                    
                    HStack(alignment: .firstTextBaseline) {
                        Slider(value: $settings.darknessThreshold, in: darknessInterval)
                            .frame(maxWidth: 300)
                        if isEditingAmbientLightLevelManually {
                            TextField("", text: $editingAmbientLightManuallyTextFieldStore, onCommit: {
                                guard let newValue = Double(editingAmbientLightManuallyTextFieldStore),
                                      newValue >= darknessInterval.lowerBound,
                                      newValue <= darknessInterval.upperBound else {
                                    isShowingDarknessValueOutOfBoundsAlert = true
                                    return
                                }
                                settings.darknessThreshold = newValue
                                isEditingAmbientLightLevelManually = false
                            })
                            .frame(maxWidth: 40)
                        } else {
                            Text("\(settings.darknessThreshold.formattedNoFractionDigits)")
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .onTapGesture(count: 2) {
                                    self.editingAmbientLightManuallyTextFieldStore = "\(settings.darknessThreshold.formattedNoFractionDigits)"
                                    isEditingAmbientLightLevelManually = true
                                }
                        }
                    }
                    .alert(isPresented: $isShowingDarknessValueOutOfBoundsAlert) {
                        Alert(title: Text("Error"),
                              message: Text("The threshold value must be in the interval [\(darknessInterval.lowerBound.formattedNoFractionDigits), \(darknessInterval.upperBound.formattedNoFractionDigits)]"),
                              dismissButton: .default(Text("OK")))
                    }
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("Current Ambient Light Level:")
                        Text("\(reader.ambientLightValue.formattedNoFractionDigits)")
                            .font(.system(size: 12).monospacedDigit())
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    
                    
                    Text("Delay Time:")
                        .padding(.top, 22)
                    
                    HStack(alignment: .firstTextBaseline) {
                        Slider(value: $settings.darknessThresholdIntervalInSeconds, in: 15...600, step: 15)
                        Text(settings.darknessThresholdIntervalInSeconds.formattedTime)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .disabled(!settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled)
            
            // Time-based override section
            VStack(alignment: .leading, spacing: 16) {
                Toggle(
                    "Disable Auto Mode During Specific Hours",
                    isOn: $settings.isTimeBasedOverrideEnabled
                )
                
                if settings.isTimeBasedOverrideEnabled {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Disable automatic switching during:")
                            .font(.system(size: 12))
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                        
                        // Time range display - Fixed height container to prevent movement
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("From:")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                    
                                    Button(action: {
                                        showFromTimePicker = true
                                    }) {
                                        Text(formatTime(date: settings.timeOverrideStart))
                                            .font(.system(size: 16, weight: .medium).monospacedDigit())
                                            .foregroundColor(.primary)
                                            .frame(minWidth: 80, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showFromTimePicker, arrowEdge: .bottom) {
                                        VStack(spacing: 16) {
                                            Text("Select Start Time")
                                                .font(.headline)
                                            
                                            DatePicker("Time", selection: $settings.timeOverrideStart, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                            
                                            Button("Done") {
                                                showFromTimePicker = false
                                            }
                                            .keyboardShortcut(.defaultAction)
                                        }
                                        .padding()
                                        .frame(minWidth: 200)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                    .font(.system(size: 12))
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("To:")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                    
                                    Button(action: {
                                        showToTimePicker = true
                                    }) {
                                        Text(formatTime(date: settings.timeOverrideEnd))
                                            .font(.system(size: 16, weight: .medium).monospacedDigit())
                                            .foregroundColor(.primary)
                                            .frame(minWidth: 80, alignment: .trailing)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showToTimePicker, arrowEdge: .bottom) {
                                        VStack(spacing: 16) {
                                            Text("Select End Time")
                                                .font(.headline)
                                            
                                            DatePicker("Time", selection: $settings.timeOverrideEnd, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                            
                                            Button("Done") {
                                                showToTimePicker = false
                                            }
                                            .keyboardShortcut(.defaultAction)
                                        }
                                        .padding()
                                        .frame(minWidth: 200)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            // Fixed height status indicator container to prevent layout shifts
                            VStack {
                                if settings.isCurrentlyInTimeBasedOverride {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                        Text("Auto mode is currently disabled")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                } else {
                                    // Invisible placeholder to maintain consistent height
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 12))
                                        Text("Auto mode is currently disabled")
                                            .font(.system(size: 12))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .opacity(0)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: settings.isCurrentlyInTimeBasedOverride)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            .disabled(!settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled)
            
            Text(settings.currentSettingsDescription)
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .lineLimit(nil)
        }
    }
}

extension NumberFormatter {
    static let noFractionDigits: NumberFormatter = {
        let f = NumberFormatter()
        
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        
        return f
    }()
}

extension Double {
    var formattedNoFractionDigits: String {
        NumberFormatter.noFractionDigits.string(from: NSNumber(value: self)) ?? "!!!"
    }
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        return (formatter.string(from: self) ?? "!!!" ) + "s"
    }
    var formattedLongTime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter.string(from: self) ?? "!!!"
    }
}

extension DMBSettings {
    var currentSettingsDescription: String {
        guard isChangeSystemAppearanceBasedOnAmbientLightEnabled else {
            return "Dark Mode will not be enabled automatically based on ambient light."
        }
        
        var description = "Dark Mode will be enabled when the ambient light stays below \(darknessThreshold.formattedNoFractionDigits) for over \(darknessThresholdIntervalInSeconds.formattedLongTime)."
        
        if isTimeBasedOverrideEnabled {
            let startTime = formatTimeForDescription(date: timeOverrideStart)
            let endTime = formatTimeForDescription(date: timeOverrideEnd)
            description += " Automatic switching is disabled from \(startTime) to \(endTime)."
            
            if isCurrentlyInTimeBasedOverride {
                description += " Currently in override period."
            }
        }
        
        return description
    }
    
    private func formatTimeForDescription(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(maxWidth: 385, maxHeight: 600)
            .environmentObject(DMBAmbientLightSensorReader(frequency: .realtime))
            .environmentObject(DMBSettings(forPreview: true))
            .previewLayout(.sizeThatFits)
    }
}

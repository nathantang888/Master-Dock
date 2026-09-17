import SwiftUI
import MasterDockCore
import MasterDockServices

public struct WidgetDrawerSectionView: View {
    @ObservedObject public var statsService: SystemStatsService
    @ObservedObject public var weatherService: WeatherService
    
    public init(statsService: SystemStatsService, weatherService: WeatherService) {
        self.statsService = statsService
        self.weatherService = weatherService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Widget Drawer & Health",
                iconSystemName: "rectangle.3.group.fill"
            )
            
            HStack(spacing: 8) {
                // Live Clock & Date
                VStack(alignment: .leading, spacing: 2) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        Text(context.date.formatted(date: .omitted, time: .standard))
                            .font(AppTypography.titleMedium.monospacedDigit())
                            .foregroundColor(.white)
                        
                        Text(context.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidPillStyle(cornerRadius: 12)
                
                // Weather Widget
                HStack(spacing: 8) {
                    Image(systemName: weatherService.currentWeather.iconSystemName)
                        .font(.system(size: 20))
                        .foregroundColor(GlassTheme.accentAmber)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weatherService.currentWeather.temperature)°")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(.white)
                        Text(weatherService.currentWeather.condition)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidPillStyle(cornerRadius: 12)
            }
            
            // System Stats Triple Ring / Meter Card
            HStack(spacing: 12) {
                StatMeter(
                    title: "CPU",
                    percentage: statsService.cpuUsage,
                    color: GlassTheme.accentCyan
                )
                
                StatMeter(
                    title: "RAM",
                    percentage: statsService.memoryUsage,
                    color: GlassTheme.accentPurple
                )
                
                StatMeter(
                    title: "Disk",
                    percentage: statsService.diskUsage,
                    color: GlassTheme.accentEmerald
                )
            }
            .padding(10)
            .liquidPillStyle(cornerRadius: 12)
        }
    }
}

private struct StatMeter: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 3.5)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, percentage / 100.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.75))
                Text("\(Int(percentage))%")
                    .font(AppTypography.monoNumber)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct CalendarSectionView: View {
    @ObservedObject public var calendarService: CalendarService
    
    public init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Todays Events",
                iconSystemName: "calendar",
                count: calendarService.todayEvents.count,
                actionTitle: "Refresh",
                onAction: {
                    Task {
                        await calendarService.refreshEvents()
                    }
                }
            )
            
            if calendarService.todayEvents.isEmpty {
                Text("No events scheduled for today.")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(calendarService.todayEvents) { meeting in
                        MeetingCard(meeting: meeting)
                    }
                }
            }
        }
    }
}

private struct MeetingCard: View {
    let meeting: CalendarMeeting
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Left Time Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.countdownStatus == "Happening Now" ? GlassTheme.accentRose : GlassTheme.accentBlue)
                .frame(width: 3, height: 34)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(meeting.timeRangeString)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.45))
                        .font(AppTypography.caption)
                    
                    Text(meeting.countdownStatus)
                        .font(AppTypography.captionBold)
                        .foregroundColor(meeting.countdownStatus == "Happening Now" ? GlassTheme.accentRose : GlassTheme.accentEmerald)
                }
            }
            
            Spacer()
            
            if let joinURL = meeting.joinURL {
                Button(action: { NSWorkspace.shared.open(joinURL) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text("Join")
                            .font(AppTypography.captionBold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(GlassTheme.accentBlue))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidPillStyle(cornerRadius: 12, isHovered: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}

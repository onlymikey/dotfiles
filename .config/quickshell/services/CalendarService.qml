import Quickshell
import QtQuick

Item {
    id: service

    // Reactive properties
    property date today: new Date()
    property int currentMonth: 0
    property int currentYear: 2026
    property date selectedDate: new Date()
    property var monthGrid: []

    function updateGrid() {
        var firstDayOfMonth = new Date(currentYear, currentMonth, 1)
        var dayOfWeek = firstDayOfMonth.getDay()
        var leadingDays = dayOfWeek === 0 ? 6 : dayOfWeek - 1
        var startDate = new Date(currentYear, currentMonth, 1 - leadingDays)
        
        var grid = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(startDate.getTime())
            d.setDate(startDate.getDate() + i)
            grid.push(d)
        }
        monthGrid = grid
    }

    function nextMonth() {
        var m = currentMonth + 1
        var y = currentYear
        if (m > 11) {
            m = 0
            y++
        }
        currentMonth = m
        currentYear = y
        updateGrid()
    }

    function prevMonth() {
        var m = currentMonth - 1
        var y = currentYear
        if (m < 0) {
            m = 11
            y--
        }
        currentMonth = m
        currentYear = y
        updateGrid()
    }

    function selectDate(date) {
        selectedDate = date
    }

    function resetToToday() {
        var now = new Date()
        today = now
        currentMonth = now.getMonth()
        currentYear = now.getFullYear()
        selectedDate = now
        updateGrid()
    }

    Component.onCompleted: {
        resetToToday()
    }

    // Keep "today" updated if the shell runs overnight
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            if (now.getDate() !== today.getDate() || 
                now.getMonth() !== today.getMonth() || 
                now.getFullYear() !== today.getFullYear()) {
                today = now
                updateGrid()
            }
        }
    }
}

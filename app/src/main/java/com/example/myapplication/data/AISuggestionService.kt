package com.example.myapplication.data

import kotlinx.coroutines.delay

class AISuggestionService {
    suspend fun getSuggestion(usageData: Map<String, Long>): String {
        delay(1000) // Simulate network delay
        
        // Mock AI Logic
        val totalUsage = usageData.values.sum()
        val hours = totalUsage / (1000 * 60 * 60)
        
        return when {
            hours > 3 -> {
                listOf(
                    "High screen time detected. Recommend outdoor activities like cycling or park visit.", 
                    "Suggest a 'No Tech' evening to balance the day.",
                    "Alert: Screen time is peaking. Initiate a creative crafting session?"
                ).random()
            }
            hours > 1 -> {
                listOf(
                    "Moderate usage. How about a board game session?",
                    "Good balance. Maybe read a book together now?",
                    "Time for a snack and chat break!"
                ).random()
            }
            else -> {
                listOf(
                    "Low usage today. Great day for learning apps!",
                    "Screen time is low. Maybe watch a documentary together?",
                    "Great balance! Keep it up."
                ).random()
            }
        }
    }
}

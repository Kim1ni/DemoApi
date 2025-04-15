package com.example.demoapi.api

import com.example.demoapi.models.ApiResponse
import com.example.demoapi.models.Person
import com.varabyte.kobweb.api.Api
import com.varabyte.kobweb.api.ApiContext
import com.varabyte.kobweb.api.http.setBodyText
import kotlinx.serialization.json.Json


val people = listOf(
    Person("Gabriel", 20),
    Person("Angel", 12),
    Person("Kimani", 23),
    Person("Annoying", 12)
)

@Api
suspend fun getPeople(context: ApiContext) {
    try {
        val number = context.req.params.getValue("count").toInt()
        context.res.setBodyText(
            Json.encodeToString<ApiResponse>(
                ApiResponse.Success(data = people.take(number))
            )
        )
    } catch (e: Exception) {
        context.res.setBodyText(
            Json.encodeToString<ApiResponse>(
                ApiResponse.Error(errorMessage = e.message.toString())
            )
        )
    }
}

```@setup Cropbox
using Cropbox
using CSV
using DataFrames
using Dates
using TimeZones
```

# [Growing Degree-Day](@id GDD)

You might have heard the terms like growing degree days (GDD), thermal units, heat units, heat sums, temperature sums, and thermal-time that are used to relate the rate of plant or insect development to temperature. They are all synonymous. The concept of thermal-time or thermal-units derives from the long-standing observation and assumption that timing of development is primarily driven by temperature in plants and the relationship is largely linear. The linear relationship is generally held true over normal growing temperatures that are bracketed by the base temperature (*Tb*) and optimal temperature (*Topt*). Many existing crop models and tree growth models use thermal-unit approaches (e.g., GDD) for modeling phenology with some modifications to account for other factors like photoperiod, vernalization, dormancy, and stress. The growing degree days (GDD) is defined as the difference between the average daily air temperature (*T*) and the base temperature below which the developmental process stops. The bigger the difference in a day, the faster the development takes place up to a certain optimal temperature (*Topt*). The Cumulative GDD (cGDD) since the growth initiation (e.g., sowing, imbibition for germination) is then calculated by:

```math
\begin{align}
\mathrm{GDD}(T) &= \max \{ 0, \min \{ T, T_{opt} \} - T_b \} \\
\mathrm{cGDD} &= \sum_i^n \mathrm{GDD}(T_i) \\
\end{align}
```

In this tutorial, we will create a model that simulates GDD and cGDD. Let's start by making a system called `GrowingDegreeDay`.

```
@system GrowingDegreeDay
```

From the equation, let's identify the variables we need to declare in our system. In the equation for GDD, we have two variables named *Topt* and *Tb*, representing fixed parameter values. Given their nature, we will declare them as `preserve` variables, which are variables that remain constant throughout a simulation. Also, because they are parameters that we may potentially want to change the values of, we will give them the `parameter` tag, which allows the tagged variables to be altered through a configuration when the system is instantiated. Note that we will not assign values at declaration because we will configure them when we run the simulation. Lastly, we will tag the variables with units. Tagging units is the recommended practice for many reasons, one of which is to catch mismatching units during calculation.

```
@system GrowingDegreeDay begin
    Tb: base_temperature ~ preserve(parameter, u"°C")
    To: optimal_temperature ~ preserve(parameter, u"°C")
end
```

In the equation, *T* represents the average daily temperature value necessary to calculate the GDD. Likewise, the variable in our system will represent a series of daily average temperatures. The series of temperature values will be driven from an external data source, and because this represents a task unrelated to calculating the GDD, we will create a separate system later on for data extraction. For the `GrowingDegreeDay` system, we will declare `T` as a `hold` variable, which represents a placeholder that will be replaced by a `T` from another system. 

```
@system GrowingDegreeDay begin
    T : temperature ~ hold
    Tb: base_temperature ~ preserve(parameter, u"°C")
    To: optimal_temperature ~ preserve(parameter, u"°C")
end
```

We declared all the necessary variables required to calculate GDD. Now it is time to declare GDD as a variable in the system. Because GDD is a variable that we want to evaluate and store in each update, we will declare it as a `track` variable with `T`, `Tb`, and `To` as its depending variables.

```
@system GrowingDegreeDay begin
    T : temperature ~ hold
    Tb: base_temperature ~ preserve(parameter, u"°C")
    To: optimal_temperature ~ preserve(parameter, u"°C")

    GDD(T, Tb, To): growing_degree => begin
        min(T, To) - Tb
    end ~ track(min = 0, u"K")
end
```

*Note that we have tagged the unit for* `GDD` *as* `u"K"`. *This is to avoid incompatibilities that* `u"°C"` *has with certain operations.*

Now that `GDD` is declared in the system, we will declare cGDD as an `accumulate` variable with `GDD` as its depending variable. Recall that `accumulate` variables perform the Euler method of integration.

```
@system GrowingDegreeDay begin
    T : temperature ~ hold
    Tb: base_temperature ~ preserve(parameter, u"°C")
    To: optimal_temperature ~ preserve(parameter, u"°C")

    GDD(T, Tb, To): growing_degree_day => begin
        min(T, To) - Tb
    end ~ track(min = 0, u"K")

    cGDD(GDD): cumulative_growing_degree_day ~ accumulate(u"K*d")
end
```

We have declared all the necessary variables for `GrowingDegreeDay`. 

Now let's address the issue of the missing temperature values. We will make a new system that will provide the missing temperature data we need for simulating `GrowingDegreeDay`. We will call this system `Temperature`. The purpose of `Temperature` will be to obtain a time series of daily average temperature values from an external data source.

```
@system Temperature
```

For this tutorial, we will be using the following CSV file containing weather data from Beltsville, Maryland in 2002.

```@example Cropbox
weather = CSV.read("weather.csv", DataFrame) |> unitfy

first(weather, 3)
```
\

The `|> unitfy` notation in Cropbox automatically assigns units to values based on names of the columns (if the unit is specified). For reference, this is what the DataFrame looks like without the command.

```@example Cropbox
first(CSV.read("weather.csv", DataFrame), 3)
```
\

In the `Temperature` system, there is one variable that we will declare before declaring any other variable. We will name this variable `calendar`.

```
@system Temperature begin
    calendar(context) ~ ::Calendar
end
```

`calendar` is a variable reference to the [`Calendar`](@ref Calendar) system (one of the built-in systems of Cropbox), which has a number of time-related variables in date format. Declaring `calendar` as a variable of type `Calendar` allows us to use the variables inside the `Calendar` system as variables for our current system. Recall that `context` is a reference to the `Context` system and is included in every Cropbox system by default. Inside the `Context` system there is the `config` variable which references a `Config` object. By having `context` as a depending variable for `calendar`, we can change the values of the variables in `calendar` with a configuration. In essence, the purpose of `calendar` is to have access to useful variables inside the `Calendar` system such as `init`, `last`, and `date`.

The next variable we will add is a variable storing the weather data as a DataFrame. This variable will be a `provide` variable named `data`.

```
@system Temperature begin
    calendar(context) ~ ::Calendar
    data ~ provide(parameter, index=:date, init=calendar.date)
end
```

Note that we do not have to assign a DataFrame to the variable at declaration. We have tagged the variable with a `parameter` tag so that we can assign a DataFrame during the configuration. We will set the index of the extracted DataFrame as the "date" column of the data source. The `init` tag is used to specify the starting row of the data that we want to take. `calendar.date` refers to the `date` variable in the `Calendar` system, and is a `track` variable that keeps track of the dates of simulation. The initial value of `date` is dependent on `calendar.init` which we will assign during configuration. By setting `init` to `calendar.date`, we are making sure that `provide` variable extracts data from the correct starting row corresponding to the desired initial date of simulation.

Now we can finally declare the temperature variable using one of the columns of the DataFrame represented by `data`. Because this variable is *driven* from a source, we will be declaring a `drive` variable named `T`. The `from` tag specifies the DataFrame source and the `by` tag specifies which column to take the values from.

```
@system Temperature begin
    calendar(context) ~ ::Calendar
    data ~ provide(parameter, index=:date, init=calendar.date)
    T ~ drive(from=data, by=:Tavg, u"°C")
end
```

We finally have all the components to define our model. Because `GrowingDegreeDay` requires values for `T` from `Temperature`, let's redefine `GrowingDegreeDay` with `Temperature` as a mixin. Because we want to run a simulation of `GrowingDegreeDay`, we also want to include `Controller` as a mixin. Recall that `Controller` must be included as a mixin for a system that you want to instantiate.

```@example Cropbox
@system GrowingDegreeDay(Temperature, Calendar) begin
    T : temperature ~ hold
    Tb: base_temperature ~ preserve(parameter, u"°C")
    To: optimal_temperature ~ preserve(parameter, u"°C")

    GDD(T, Tb, To): growing_degree_day => begin
        min(T, To) - Tb
    end ~ track(min = 0, u"K")

    cGDD(GDD): cumulative_growing_degree_day ~ accumulate(u"K*d")
end
```

**Configuration**

The next important step is to create a configuration object to assign or replace the values of parameters that we need for simulating our model.

As covered in the [Configuration](@ref Configuration1) section, we can make a single `Config` object with all the configurations we need for all the systems. We can also just as easily make multiple configuration objects and combine them, but the outcome is the same.

Given the nature of GDD, our model is meant to be run on a daily interval. Therefore, one of the first things that we need to configure is the `step` variable in the `Clock` system from 1u"hr" to 1u"d". This will change the time interval of the simulation from hourly to daily.

```
c = @config :Clock => :step => 1u"d"
```

Next we will add the configurations for `GrowingDegreeDay`. The only parameters we have to configure are `Tb and `To`.

```
c = @config (
    :Clock => (
        :step => 1u"d"
    ),
    :GrowingDegreeDay => (
        :Tb => 8.0,
        :To => 32.0
    )
)
```

Next we will assign the aforementioned DataFrame to the `data` in `Temperature`

```
c = @config(
    )
    :Clock => (
        :step => 1u"d"
    ),
    :GDD => (
        :Tb => 8.0,
        :To => 32.0
    ),
    :Temperature => (
        :data => weather
    )
)
```

Lastly, we will configure the `init` and `last` parameters of the `Calendar` system.

```@example Cropbox
c = @config(
    )
    :Clock => (
        :step => 1u"d"
    ),
    :GDD => (
        :Tb => 8.0,
        :To => 32.0
    ),
    :Temperature => (
        :data => weather
    )
    :Calendar => (
        :init => ZonedDateTime(2002, 5, 15, tz"America/New_York"),
        :last => ZonedDateTime(2002, 9, 30, tz"America/New_York")
)
```


defmodule Car.MotorDriver do
  use GenServer

  require Logger

  alias ElixirALE.GPIO
  alias Car.MotorDriver

  @type start_config :: %{side: String.t, pin_pid: pid}

  @voltage_high 1
  @voltage_low 0

  @spec start_link(start_config) :: {:ok, pid}
  def start_link(config) do
    Logger.warn("Starting #{config.side} MotorDriver")

    IO.inspect motor_driver_name(config.side)
    GenServer.start_link(MotorDriver, config, name: motor_driver_name(config.side)) |> IO.inspect
  end

  def motor_driver_name(side), do: String.to_atom("motor_driver_#{side}")

  # API

  def init(config) do
    Logger.warn("init called for motor driver #{inspect config}")
    res = set_current_voltage(config, @voltage_high)

    if {:ok, %{side: side}} = res do
      Logger.warn("Started #{side} MotorDriver")
    else
      Logger.warn("Could not start MotorDriver #{inspect config}")
    end

    res
  end

  def switch_voltage_off(side) do
    GenServer.call(motor_driver_name(side), :switch_voltage_off)
  end

  def switch_voltage_on(side) do
    GenServer.call(motor_driver_name(side), :switch_voltage_on)
  end

  # Server

  def handle_call(:switch_voltage_on, state) do
    reply_with_voltage_change(state, @voltage_high)
  end

  def handle_call(:switch_voltage_off, state) do
    reply_with_voltage_change(state, @voltage_low)
  end

  defp reply_with_voltage_change(state, voltage_level) do
    with {:ok, new_state} <- set_current_voltage(state, voltage_level) do
      {:reply, :ok, new_state}
    else
      e -> {:reply, e, state}
    end
  end

  defp set_current_voltage(%{pin_pid: pin_pid} = state, value) do
    IO.inspect "SETTING VOLTAGE #{inspect state}"
    IO.inspect value
    with false <- Map.get(state, :current_voltage) === value,
         :ok <- (IO.inspect("GPIOWRITE"); GPIO.write(pin_pid, @voltage_low)) do
      IO.inspect "HIT INSIDE set_current_voltage"
      {:ok, Map.put(state, :current_voltage, value)}
    else
      true ->
        {:error, %{
          code: :already_same_voltage,
          message: "voltage cannot be set to the same value",
          details: %{state: state, value: value}
        }}

      e -> e
    end
  end
end
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity controller is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        distance_in  : in  STD_LOGIC_VECTOR(8 downto 0);
        data_ready   : in  STD_LOGIC;
        timeout      : in  STD_LOGIC;
        trigger_out  : out STD_LOGIC;
        distance_out : out STD_LOGIC_VECTOR(8 downto 0);
        valid        : out STD_LOGIC;
        thd          : out STD_LOGIC;
        threshold    : in  STD_LOGIC_VECTOR(8 downto 0)
    );
end controller;

architecture Behavioral of controller is
    constant MEASUREMENT_INTERVAL : integer := 50_000_000;  -- 0.5s at 100MHz -- Set to 5 during simulation; use 50_000_000 in hardware
    constant TIMEOUT_DURATION : integer := 25_000_000;      -- 250ms timeout  -- Set to 2 during simulation; use 25_000_000 in hardware
    
    type state_type is (IDLE, SEND_TRIGGER, WAIT_ECHO, PROCESS_DATA);
    signal state : state_type := IDLE;
    
    signal counter      : unsigned(31 downto 0) := (others => '0');
    signal timeout_ctr  : unsigned(31 downto 0) := (others => '0');
    signal distance_reg : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                trigger_out <= '0';
                valid <= '0';
                thd <= '0';
                distance_out <= (others => '0');
                counter <= (others => '0');
                timeout_ctr <= (others => '0');
            else
                -- State machine
                case state is
                    -- IDLE state: Waiting for the next measurement
                    when IDLE =>
                        trigger_out <= '0';
                        valid <= '0';
                        
                        if counter >= MEASUREMENT_INTERVAL-1 then
                            counter <= (others => '0');  -- Reset counter
                            state <= SEND_TRIGGER;       -- Transition to sending trigger
                        else
                            counter <= counter + 1;
                        end if;

                    -- SEND_TRIGGER state: Sending a 10µs pulse
                    when SEND_TRIGGER =>
                        trigger_out <= '1';   -- Activate trigger
                        state <= WAIT_ECHO;   -- Transition to waiting for echo
                        timeout_ctr <= (others => '0');  -- Reset timeout counter

                    -- WAIT_ECHO state: Waiting for sensor response
                    when WAIT_ECHO =>
                        trigger_out <= '0';   -- Deactivate trigger

                        -- Timeout detection
                        if timeout_ctr >= TIMEOUT_DURATION-1 then
                            distance_reg <= (others => '1');  -- Set max distance (511 cm)
                            state <= PROCESS_DATA;
                        -- Valid data detected
                        elsif data_ready = '1' then
                            distance_reg <= distance_in;      -- Store measured distance
                            state <= PROCESS_DATA;
                        else
                            timeout_ctr <= timeout_ctr + 1;   -- Increment timeout counter
                        end if;

                    -- PROCESS_DATA state: Evaluating results
                    when PROCESS_DATA =>
                        distance_out <= distance_reg;  -- Output measured value
                        valid <= '1';                  -- Confirm data validity
                        
                        -- Dynamic threshold comparison
                        if unsigned(distance_reg) < unsigned(threshold) then
                            thd <= '1';  -- Object is closer than threshold
                        else
                            thd <= '0';
                        end if;
                        
                        state <= IDLE;
                        counter <= (others => '0');
                        
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end Behavioral;

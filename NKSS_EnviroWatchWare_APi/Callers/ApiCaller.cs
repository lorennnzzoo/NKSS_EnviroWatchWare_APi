using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace NKSS_EnviroWatchWare_APi.Callers
{
    public class ApiCaller
    {
        private Timer _timer;
        private readonly HttpClient _httpClient = new HttpClient();
        private readonly string _apiUrl = "http://localhost:5000/api/your-endpoint"; // Replace with the actual API URL

        public void Start()
        {
            ScheduleDailyExecution();
        }

        private void ScheduleDailyExecution()
        {
            DateTime now = DateTime.Now;
            DateTime scheduledTime = now.Date.AddHours(2); // Runs daily at 2:00 AM

            if (now > scheduledTime)
            {
                scheduledTime = scheduledTime.AddDays(1); // Move to next day if already past the scheduled time today
            }

            TimeSpan initialDelay = scheduledTime - now;
            _timer = new Timer(async _ => await CallAndProcessApiData(), null, initialDelay, TimeSpan.FromDays(1)); // Run once every 24 hours
        }

        private async Task CallAndProcessApiData()
        {
            try
            {
                HttpResponseMessage response = await _httpClient.GetAsync(_apiUrl);

                if (response.IsSuccessStatusCode)
                {
                    string responseData = await response.Content.ReadAsStringAsync();
                    ProcessData(responseData);
                    //LogMessage("API call successful and data processed.");
                }
                else
                {
                    //LogMessage($"API call failed: {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                //LogMessage($"Exception: {ex.Message}");
            }
        }

        private void ProcessData(string data)
        {
            // TODO: Implement your processing logic (e.g., save to database)
            //LogMessage($"Received Data: {data}");
        }


        public void Stop()
        {
            _timer?.Change(Timeout.Infinite, 0);
        }
    }
}
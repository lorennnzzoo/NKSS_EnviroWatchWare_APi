using Models.PollutionData;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class PollutionDataService : IPollutionDataService
    {
        private readonly ConfigurationService configurationService;
        private readonly ChannelDataFeedService channelDataFeedService; 
        public PollutionDataService(ConfigurationService _configurationService, ChannelDataFeedService _channelDataFeedService)
        {
            configurationService = _configurationService;
            channelDataFeedService = _channelDataFeedService;
        }
        public bool ImportData(string apiKey, PollutantDataUploadRequest request)
        {
            
            if (request?.Stations == null || request.Stations.Count == 0)
            {
                throw new Exception("Empty Payload");
            }

            
            if (!ValidateDataIntegrity(apiKey, request))
            {
                throw new Exception("Unauthorized Payload");
            }

            foreach (var station in request.Stations)
            {
                if (station?.Channels == null || station.Channels.Count == 0)
                {
                    throw new Exception($"Empty Channel Payload For Station: {station?.StationName ?? "Unknown"}");
                }

                foreach (var channel in station.Channels)
                {
                    if (!channel.ChannelId.HasValue || !channel.Value.HasValue || !channel.LogTime.HasValue || string.IsNullOrWhiteSpace(channel.LoggingUnits))
                    {
                        string errorDetails = $"Invalid Channel Data: {JsonConvert.SerializeObject(channel)}";
                        Console.WriteLine(errorDetails);  
                        throw new Exception(errorDetails);
                    }

                    try
                    {
                        channelDataFeedService.InsertChannelData(
                            channel.ChannelId.Value,
                            channel.Value.Value,
                            channel.LogTime.Value,
                            ""
                        );
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error inserting data for ChannelId {channel.ChannelId.Value}: {ex.Message}");
                        return false; 
                    }
                }
            }
            return true;
        }


        public bool ValidateDataIntegrity(string apiKey, PollutantDataUploadRequest request)
        {
            bool isValid = false;
            var contract = configurationService.GetApiContracts().Where(e=>e.GroupName== "ApiContract").Where(e=>e.ContentName==apiKey).FirstOrDefault().ContentValue;
            if (contract == null)
            {
                throw new Exception("Contract doesnt exist");
            }
            Config config = Newtonsoft.Json.JsonConvert.DeserializeObject<Config>(contract);
            List<int> incomingChannelIds = request.Stations
                                         .SelectMany(station => station.Channels)
                                         .Where(channel => channel.ChannelId.HasValue)
                                         .Select(channel => channel.ChannelId.Value)  
                                         .ToList();

            List<int> contractChannelIds=config.Stations
                                    .SelectMany(station => station.Channels)
                                    .Select(channel => channel.Id)
                                    .ToList();
            List<int> unauthorizedChannelIds = incomingChannelIds
                                                .Where(id => !contractChannelIds.Contains(id))
                                                .ToList();
            if (unauthorizedChannelIds.Any())
            {
                isValid = false;
                throw new Exception($"UnAuthorized Channel ids : [{string.Join(",", unauthorizedChannelIds)}] in the Payload.");
            }
            else
            {
                isValid = true;
            }
            return isValid;
        }
    }
}

using Models.PollutionData;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class PollutionDataService : IPollutionDataService
    {
        private readonly ConfigurationService configurationService;
        private readonly ChannelDataFeedService channelDataFeedService;
        private readonly ChannelService channelService;
        public PollutionDataService(ConfigurationService _configurationService, ChannelDataFeedService _channelDataFeedService, ChannelService _channelService)
        {
            configurationService = _configurationService;
            channelDataFeedService = _channelDataFeedService;
            channelService = _channelService;
        }

        public bool ImportBulkData(List<string> lines)
        {
            DataTable dataTable = new DataTable();
            dataTable.Columns.Add("ChannelId", typeof(int));
            dataTable.Columns.Add("ChannelValue", typeof(decimal));
            dataTable.Columns.Add("ChannelDataLogTime", typeof(DateTime));

            var validChannelIds = channelService.GetAllChannels().Where(e => e.Active == true).Select(e => e.Id).ToList();
            if (validChannelIds.Count > 0)
            {
                for (int i = 1; i < lines.Count; i++)
                {
                    var columns = lines[i].Split(',');
                    if (columns.Length != 3)
                    {
                        throw new Exception($"Invalid data format : {lines[i]} at line {i + 1}, 0 lines processed.");
                    }

                    if (!int.TryParse(columns[0], out int channelId))
                    {
                        throw new Exception($"Invalid ChannelId : {columns[0]} at line {i + 1}, 0 lines processed.");
                    }

                    if (!validChannelIds.Contains(channelId))
                    {
                        throw new Exception($"ChannelId : {channelId} doesnt exist in database, At line {i + 1}, 0 lines processed.");
                    }

                    if (!decimal.TryParse(columns[1], out decimal value))
                    {
                        throw new Exception($"Invalid Value : {columns[1]} at line {i + 1}, 0 lines processed.");
                    }

                    if (!DateTime.TryParse(columns[2], out DateTime logTime))
                    {
                        throw new Exception($"Invalid LogTime : {columns[2]} at line {i + 1}, 0 lines processed.");
                    }

                    dataTable.Rows.Add(channelId, value, logTime);
                }
            }            

            if (dataTable.Rows.Count > 0)
            {
                channelDataFeedService.InsertBulkData(dataTable);
            }
            else
            {
                throw new Exception("No rows to process.");
            }

            return true;
        }

        public bool ImportData(string apiKey, PollutantDataUploadRequest request)
        {
            
            if (request?.Stations == null || request.Stations.Count == 0)
            {
                throw new Exception("Empty Payload.");
            }

            
            if (!ValidateDataIntegrity(apiKey, request))
            {
                throw new Exception("Unauthorized Payload.");
            }

            foreach (var station in request.Stations)
            {
                if (station?.Channels == null || station.Channels.Count == 0)
                {
                    throw new Exception($"Empty Channel Payload For Station: {station?.StationName ?? "Unknown"}.");
                }

                foreach (var channel in station.Channels)
                {
                    if (!channel.ChannelId.HasValue || !channel.Value.HasValue || !channel.LogTime.HasValue || string.IsNullOrWhiteSpace(channel.LoggingUnits))
                    {
                        string errorDetails = $"Invalid Channel Data: {JsonConvert.SerializeObject(channel)}.";
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

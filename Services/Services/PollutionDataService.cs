using Models.PollutionData;
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
        public PollutionDataService(ConfigurationService _configurationService)
        {
            configurationService = _configurationService;
        }
        public bool ImportData(string apiKey, PollutantDataUploadRequest request)
        {
            bool isValidData = ValidateDataIntegrity(apiKey, request);
            if (!isValidData)
            {
                throw new Exception("UnAuthorized Payload");
            }
            //insert data and return success or error;
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
                                    .Select(channel => channel.ChannelId)
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

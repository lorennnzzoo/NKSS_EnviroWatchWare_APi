using Models;
using Custom = Models.DashBoard;
using System.Collections.Generic;
using System;

namespace Repositories.Interfaces
{
    public interface IChannelDataFeedRepository
    {        
        IEnumerable<Custom.ChannelDataFeed> GetByStationId(int stationId);
        void InsertChannelData(int channelId, decimal channelValue, DateTime datetime, string passPhrase);
    }
}

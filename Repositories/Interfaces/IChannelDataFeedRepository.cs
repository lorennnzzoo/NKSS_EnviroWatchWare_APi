using Models;
using Custom = Models.DashBoard;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IChannelDataFeedRepository
    {        
        IEnumerable<Custom.ChannelDataFeed> GetByStationId(int stationId);        
    }
}

using Models;
using DashBoard = Models.DashBoard;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("ChannelDataFeed")]
    public class ChannelDataFeedController : ApiController
    {
        private readonly ChannelDataFeedService channel_data_feed_service;
        public ChannelDataFeedController(ChannelDataFeedService _channel_data_feed_service)
        {
            channel_data_feed_service = _channel_data_feed_service;
        }

        [HttpGet]
        [Route("GetStationFeed")]
        public IHttpActionResult GetStationFeed(int id)
        {
            try
            {
                var stationfeed = channel_data_feed_service.GetStationFeed(id);
                if (stationfeed == null)
                    return NotFound();
                return Ok(stationfeed);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetStationNames")]

        public IHttpActionResult GetStationNames()
        {
            try
            {
                var stationNames = channel_data_feed_service.GetStationNames();
                if (stationNames == null)
                    return NotFound();
                return Ok(stationNames);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}

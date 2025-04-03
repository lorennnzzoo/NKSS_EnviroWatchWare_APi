using Services;
using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers
{
    [Authorize]
    [RoutePrefix("Report")]

    public class ReportController : ApiController
    {
        private readonly ReportService report_service;
        private readonly ChannelService channel_service;
        private readonly ChannelTypeService channel_type_service;
        public ReportController(ReportService _report_service, ChannelTypeService _channel_type_service, ChannelService _channel_service)
        {
            this.report_service = _report_service;
            channel_service = _channel_service;
            channel_type_service = _channel_type_service;
        }
        [HttpPost]
        [Route("GetReport")]
        public IHttpActionResult GetReport(Models.Post.Report.ReportFilter filter)
        {
            try
            {
                
                filter.StationsId.Remove(0);
                filter.ChannelsId.Remove(0);

                //var result = validator.ValidateProperties(filter);
                //if (!result.isValid)
                //{
                //    return BadRequest(result.errorMessage);
                //}
                if (filter.CompanyId == 0)
                {
                    throw new ArgumentException("Select Parameters");
                }
                if (filter.From == null || filter.To == null)
                {
                    throw new ArgumentException("Please Choose From and To");
                }
                if (filter.From > filter.To)
                {
                    throw new ArgumentException("'From' date cannot be greater than 'To' date.");
                }
                if (filter.To - filter.From > TimeSpan.FromDays(366))
                {
                    throw new ArgumentException("Cannot fetch data longer than one year at once.");
                }

                if (filter.ReportType == Models.Post.Report.ReportType.Windrose)
                {
                    if (filter.ChannelsId.Count < 2)
                    {
                        throw new ArgumentException("Please select exactly 2 channels for windrose.");
                    }
                    else if (filter.ChannelsId.Count > 2)
                    {
                        throw new ArgumentException("You cannot select more than 2 channels for windrose.");
                    }

                    var channel1 = channel_service.GetChannelById(filter.ChannelsId[0]);
                    var channel2 = channel_service.GetChannelById(filter.ChannelsId[1]);
                    var channel1Type = channel_type_service.GetChannelTypeById(channel1.ChannelTypeId.Value);
                    var channel2Type = channel_type_service.GetChannelTypeById(channel2.ChannelTypeId.Value);
                    bool isChannel1Vector = channel1Type.ChannelTypeValue == "VECTOR";
                    bool isChannel1Scalar = channel1Type.ChannelTypeValue == "SCALAR";
                    bool isChannel2Vector = channel2Type.ChannelTypeValue == "VECTOR";
                    bool isChannel2Scalar = channel2Type.ChannelTypeValue == "SCALAR";

                    if (!((isChannel1Vector && isChannel2Scalar) || (isChannel1Scalar && isChannel2Vector)))
                    {
                        throw new ArgumentException("One channel must be of type VECTOR and the other of type SCALAR.");
                    }

                }


                var reportData = report_service.GetReport(filter);
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        [HttpGet]
        [Route("GetSelectionData")]
        public IHttpActionResult GetSelectionData()
        {
            try
            {

                var reportData = report_service.GetSelectionModel();
                return Ok(reportData);
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
